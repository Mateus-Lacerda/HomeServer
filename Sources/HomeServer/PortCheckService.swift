import Foundation

struct PortCheckService {
    
    enum Status {
        case available
        case occupied(process: String)
    }
    
    static func checkPort(_ port: Int) -> Status {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", ":\(port)", "-sTCP:LISTEN"] // Only listen ports
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // lsof found something
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse output to find process name
                    // Output format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
                    let lines = output.split(separator: "\n")
                    if lines.count > 1 {
                        let dataLine = lines[1] // Skip header
                        let parts = dataLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                        if let command = parts.first {
                            return .occupied(process: String(command))
                        }
                    }
                    return .occupied(process: "Unknown")
                }
            }
        } catch {
            print("Failed to run lsof: \(error)")
        }
        
        return .available
    }
}
