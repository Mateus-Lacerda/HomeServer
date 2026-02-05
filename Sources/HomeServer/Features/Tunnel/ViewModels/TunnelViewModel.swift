import Foundation
import SwiftUI

@MainActor
class TunnelViewModel: ObservableObject {
  @Published var isConnected = false
  @Published var isConnecting = false
  @Published var error: String?

  private var process: Process?
  private var askpassScriptURL: URL?

  var onTermination: (() -> Void)?

  func startTunnel(session: SavedSession, ports: [RemotePort], password: String?) async {
    isConnecting = true
    error = nil

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
      }
    } catch {
      self.error = "Failed to start SSH: \(error.localizedDescription)"
      self.isConnecting = false
      cleanup()
    }
  }

  func stopTunnel() {
    process?.terminate()
    cleanup()
    isConnected = false
  }

  private func cleanup() {
    process = nil
    if let url = askpassScriptURL {
      try? FileManager.default.removeItem(at: url)
      askpassScriptURL = nil
    }
  }
}
