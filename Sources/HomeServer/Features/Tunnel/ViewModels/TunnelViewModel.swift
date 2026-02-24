import Foundation
import SwiftUI

struct TunnelState: Codable {
  var sessionId: UUID
  var ports: [[Int]]  // [[local, remote], ...]
  var pid: Int32?
  var controlMasterPath: String?

  static var filePath: URL {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".homeserver")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("active_tunnels.json")
  }

  func save() {
    if let data = try? JSONEncoder().encode(self) {
      try? data.write(to: Self.filePath)
    }
  }

  static func load() -> TunnelState? {
    guard let data = try? Data(contentsOf: filePath) else { return nil }
    return try? JSONDecoder().decode(TunnelState.self, from: data)
  }

  static func remove() {
    try? FileManager.default.removeItem(at: filePath)
  }
}

@MainActor
class TunnelViewModel: ObservableObject {
  @Published var isConnected = false
  @Published var isConnecting = false
  @Published var error: String?

  private var process: Process?
  private var askpassScriptURL: URL?
  private var controlMasterPath: String?
  private var forwardedPorts: [RemotePort] = []
  private var controlMasterSession: SavedSession?

  var onTermination: (() -> Void)?

  private func checkControlMaster(session: SavedSession) -> String? {
    let controlPath = NSString("~/.ssh/control-%r@%h:%p").expandingTildeInPath

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    process.arguments = [
      "-O", "check",
      "-o", "ControlPath=\(controlPath)",
      "\(session.username)@\(session.ipAddress)",
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0 ? controlPath : nil
    } catch {
      return nil
    }
  }

  func startTunnel(session: SavedSession, ports: [RemotePort], password: String?) async {
    isConnecting = true
    error = nil

    // Check for active ControlMaster
    if let path = checkControlMaster(session: session) {
      await startWithControlMaster(session: session, ports: ports, controlPath: path)
      return
    }

    // No ControlMaster — spawn SSH process directly
    await startWithProcess(session: session, ports: ports, password: password)
  }

  private func startWithControlMaster(session: SavedSession, ports: [RemotePort], controlPath: String) async {
    var failed: [String] = []

    for port in ports {
      let forwardSpec = "\(port.localPort):localhost:\(port.remotePort)"
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
      proc.arguments = [
        "-O", "forward",
        "-L", forwardSpec,
        "-o", "ControlPath=\(controlPath)",
        "\(session.username)@\(session.ipAddress)",
      ]

      let pipe = Pipe()
      proc.standardError = pipe

      do {
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          let msg = String(data: data, encoding: .utf8) ?? "unknown error"
          failed.append("Port \(port.localPort): \(msg)")
        }
      } catch {
        failed.append("Port \(port.localPort): \(error.localizedDescription)")
      }
    }

    if failed.isEmpty {
      self.controlMasterPath = controlPath
      self.forwardedPorts = ports
      self.controlMasterSession = session
      self.isConnected = true
      persistState(session: session, ports: ports)
    } else {
      self.error = "ControlMaster forward failed:\n" + failed.joined(separator: "\n")
    }
    self.isConnecting = false
  }

  private func startWithProcess(session: SavedSession, ports: [RemotePort], password: String?) async {
    var args = [
      "-N", "-o", "StrictHostKeyChecking=accept-new", "-o", "ServerAliveInterval=15", "-o",
      "ExitOnForwardFailure=yes",
    ]

    if !session.keyPath.isEmpty, session.keyPath != "MANUAL" {
      args.append(contentsOf: ["-i", session.keyPath])
    }

    for port in ports {
      args.append(contentsOf: ["-L", "\(port.localPort):localhost:\(port.remotePort)"])
    }

    args.append("\(session.username)@\(session.ipAddress)")

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    task.arguments = args

    var env = ProcessInfo.processInfo.environment
    if let password = password, !password.isEmpty {
      let script = "#!/bin/sh\necho \"\(password)\"\n"
      let tempDir = FileManager.default.temporaryDirectory
      let scriptURL = tempDir.appendingPathComponent("ssh_askpass_\(UUID().uuidString).sh")
      self.askpassScriptURL = scriptURL

      do {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        env["SSH_ASKPASS"] = scriptURL.path
        env["DISPLAY"] = ":0"
        env["SSH_ASKPASS_REQUIRE"] = "force"
      } catch {
        self.error = "Failed to setup auth: \(error.localizedDescription)"
        self.isConnecting = false
        return
      }
    }
    task.environment = env

    let pipe = Pipe()
    task.standardError = pipe

    task.terminationHandler = { [weak self] proc in
      Task { @MainActor in
        self?.cleanup()
        self?.isConnected = false
        self?.isConnecting = false
        TunnelState.remove()

        if proc.terminationStatus != 0 {
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown SSH error"
          self?.error = "Tunnel Error: \(errorMsg)"
        }

        self?.onTermination?()
      }
    }

    do {
      try task.run()
      self.process = task
      try await Task.sleep(nanoseconds: 500_000_000)
      if task.isRunning {
        self.isConnected = true
        self.isConnecting = false
        persistState(session: session, ports: ports)
      }
    } catch {
      self.error = "Failed to start SSH: \(error.localizedDescription)"
      self.isConnecting = false
      cleanup()
    }
  }

  func stopTunnel() {
    if let controlPath = controlMasterPath, let session = controlMasterSession {
      // Cancel forwards via ControlMaster
      for port in forwardedPorts {
        let forwardSpec = "\(port.localPort):localhost:\(port.remotePort)"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = [
          "-O", "cancel",
          "-L", forwardSpec,
          "-o", "ControlPath=\(controlPath)",
          "\(session.username)@\(session.ipAddress)",
        ]
        try? proc.run()
        proc.waitUntilExit()
      }
      controlMasterPath = nil
      forwardedPorts = []
      controlMasterSession = nil
      isConnected = false
      TunnelState.remove()
      onTermination?()
    } else {
      process?.terminate()
      cleanup()
      isConnected = false
      TunnelState.remove()
    }
  }

  private func cleanup() {
    process = nil
    if let url = askpassScriptURL {
      try? FileManager.default.removeItem(at: url)
      askpassScriptURL = nil
    }
  }

  private func persistState(session: SavedSession, ports: [RemotePort]) {
    let state = TunnelState(
      sessionId: session.id,
      ports: ports.map { [$0.localPort, $0.remotePort] },
      pid: process?.processIdentifier,
      controlMasterPath: controlMasterPath
    )
    state.save()
  }

  func reclaim(state: TunnelState, session: SavedSession, ports: [RemotePort]) {
    if let pid = state.pid {
      // Verify PID is alive and is ssh
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/bin/ps")
      proc.arguments = ["-p", "\(pid)", "-o", "comm="]
      let pipe = Pipe()
      proc.standardOutput = pipe
      do {
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let comm = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard comm.contains("ssh") else {
          TunnelState.remove()
          return
        }
      } catch {
        TunnelState.remove()
        return
      }
    } else if let cmPath = state.controlMasterPath {
      self.controlMasterPath = cmPath
      self.controlMasterSession = session
      self.forwardedPorts = ports
    }

    self.isConnected = true
  }
}
