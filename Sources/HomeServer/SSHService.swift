import Foundation
import AppKit

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
            "-o", "StrictHostKeyChecking=accept-new" // Simplifies first-time connection
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
    
    static func runCommand(ip: String, user: String, keyPath: String?, command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10"
        ]
        
        if let keyPath = keyPath, !keyPath.isEmpty, keyPath != "MANUAL" {
            args.append(contentsOf: ["-i", keyPath])
        }
        
        args.append("\(user)@\(ip)")
        args.append(command)
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe // Capture stderr too just in case
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "SSH", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        
        return output
    }
}
