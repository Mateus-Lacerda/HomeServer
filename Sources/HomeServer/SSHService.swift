import AppKit
import Foundation

public struct SSHCommandOutput {
  public let stdout: String?
  public let stderr: String?
  public let exitCode: Int?
}

struct SSHService {
  enum ConnectionResult {
    case success
    case failure(output: String)
  }

  /// Attempts to connect non-interactively to check if credentials/keys work.
  static func testConnection(ip: String, user: String, keyPath: String?) async -> ConnectionResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

    var args = [
      "-o", "BatchMode=yes",
      "-o", "ConnectTimeout=5",
      "-o", "StrictHostKeyChecking=accept-new",  // Simplifies first-time connection
    ]

    if let keyPath = keyPath, !keyPath.isEmpty, keyPath != "MANUAL" {
      args.append(contentsOf: ["-i", keyPath])
    }

    args.append("\(user)@\(ip)")
    args.append("echo connected")

    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""

      if process.terminationStatus == 0 {
        return .success
      } else {
        return .failure(output: output)
      }
    } catch {
      return .failure(output: error.localizedDescription)
    }
  }

  /// Opens the system default Terminal with the SSH command for manual debugging/password entry.
  static func openTerminalForDebugging(ip: String, user: String, keyPath: String?) {
    var sshCommand = "ssh \(user)@\(ip)"
    if let keyPath = keyPath, !keyPath.isEmpty, keyPath != "MANUAL" {
      sshCommand = "ssh -i \(keyPath) \(user)@\(ip)"
    }

    let appleScript = """
      tell application "Terminal"
          activate
          do script "\(sshCommand)"
      end tell
      """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
      scriptObject.executeAndReturnError(&error)
      if let error = error {
        print("AppleScript Error: \(error)")
      }
    }
  }

  // Original runCommand, now simplified to use runCommandDetailed and throw only on non-zero exit.
  static func runCommand(ip: String, user: String, keyPath: String?, command: String) async throws
    -> String
  {
    let output = try await runCommandDetailed(
      ip: ip, user: user, keyPath: keyPath, command: command)
    if output.exitCode != 0 {
      let errorMsg =
        output.stderr ?? output.stdout ?? "Command failed with exit code \(output.exitCode ?? -1)"
      throw NSError(
        domain: "SSH", code: output.exitCode ?? -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
    }
    return output.stdout ?? ""
  }

  // New detailed command runner
  static func runCommandDetailed(ip: String, user: String, keyPath: String?, command: String)
    async throws -> SSHCommandOutput
  {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

    var args = [
      "-o", "BatchMode=yes",
      "-o", "ConnectTimeout=10",
    ]

    if let keyPath = keyPath, !keyPath.isEmpty, keyPath != "MANUAL" {
      args.append(contentsOf: ["-i", keyPath])
    }

    args.append("\(user)@\(ip)")
    args.append(command)

    process.arguments = args

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8)
    let stderr = String(data: stderrData, encoding: .utf8)

    return SSHCommandOutput(
      stdout: stdout, stderr: stderr, exitCode: Int(process.terminationStatus))
  }

}
