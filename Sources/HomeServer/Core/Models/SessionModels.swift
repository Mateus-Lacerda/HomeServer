import Foundation

public struct PortLayout: Identifiable, Codable, Equatable {
  public var id: UUID = UUID()
  public var name: String
  public var mappings: [Int: Int]  // Key: Remote Port, Value: Local Port

  public init(id: UUID = UUID(), name: String, mappings: [Int : Int]) {
    self.id = id
    self.name = name
    self.mappings = mappings
  }
}

public struct CustomPortMapping: Identifiable, Codable, Equatable {
  public var id: UUID = UUID()
  public var name: String
  public var remotePort: Int
  public var localPort: Int

  public init(id: UUID = UUID(), name: String, remotePort: Int, localPort: Int) {
    self.id = id
    self.name = name
    self.remotePort = remotePort
    self.localPort = localPort
  }
}

public struct SavedSession: Identifiable, Codable, Equatable {
  public var id: UUID = UUID()
  public var name: String
  public var ipAddress: String
  public var username: String
  public var keyPath: String
  public var environment: String = "Docker"
  public var savedLayouts: [PortLayout] = []
  public var customPorts: [CustomPortMapping] = []

  public init(id: UUID = UUID(), name: String, ipAddress: String, username: String, keyPath: String, environment: String = "Docker", savedLayouts: [PortLayout] = [], customPorts: [CustomPortMapping] = []) {
    self.id = id
    self.name = name
    self.ipAddress = ipAddress
    self.username = username
    self.keyPath = keyPath
    self.environment = environment
    self.savedLayouts = savedLayouts
    self.customPorts = customPorts
  }
}
