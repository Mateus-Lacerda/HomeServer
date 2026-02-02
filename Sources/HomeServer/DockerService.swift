import Foundation

struct DockerContainer {
  let name: String
  let ports: [Int]  // List of EXPOSED/Mapped public ports on the remote
}

struct DockerService {
  static func fetchContainers(ip: String, user: String, keyPath: String?) async throws
    -> [DockerContainer]
  {
    // Format: Name|Ports
    // Example output of docker ps: "web|0.0.0.0:80->80/tcp, :::80->80/tcp"
    let command = "docker ps --format '{{.Names}}|{{.Ports}}'"

    let output = try await SSHService.runCommand(
      ip: ip, user: user, keyPath: keyPath, command: command)

    return parseDockerOutput(output)
  }

  static func parseDockerOutput(_ output: String) -> [DockerContainer] {
    var containers: [DockerContainer] = []

    let lines = output.split(separator: "\n")
    for line in lines {
      let parts = line.split(separator: "|")
      guard parts.count >= 2 else { continue }

      let name = String(parts[0])
      let portString = String(parts[1])

      let ports = extractPorts(from: portString)

      if !ports.isEmpty {
        containers.append(DockerContainer(name: name, ports: ports))
      }
    }

    return containers
  }

  private static func extractPorts(from raw: String) -> [Int] {
    // Regex to find "hostPort->containerPort"
    // We care about the HOST port (the left side of ->) or just exposed ports.
    // Format examples: "0.0.0.0:5432->5432/tcp", "80/tcp", "127.0.0.1:8080->80/tcp"

    // Simple logic: Look for patterns like ":<number>->" or just numbers if strict
    // But `docker ps` string format is messy.
    // Let's look for "X->Y" and take X.

    var ports: Set<Int> = []
    let components = raw.split(separator: ",")

    for comp in components {
      if comp.contains("->") {
        // "0.0.0.0:5432->5432/tcp"
        let arrowSplit = comp.split(separator: "->")
        if let leftSide = arrowSplit.first {
          // "0.0.0.0:5432" or ":::5432"
          if let portRange = leftSide.split(separator: ":").last,
            let port = Int(portRange)
          {
            ports.insert(port)
          }
        }
      }
    }

    return Array(ports).sorted()
  }
}
