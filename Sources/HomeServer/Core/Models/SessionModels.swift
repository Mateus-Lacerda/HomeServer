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

public struct SyncService: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID = UUID()
  public var mainRepoPath: String = ""  // Path to the main .git repo on the remote
  public var remoteWorktreePath: String = ""  // Path to the worktree folder on the remote
  public var branch: String = "main"
  public var syncInterval: Int = 0  // 0 for manual
  public var hotReloadCommand: String = ""
  public var triggerOnChanges: Bool = false
  public var worktreeRemoteName: String = "local-dev"  // Name of the remote on the worktree
  public var macUser: String = NSUserName()
  public var macPath: String = ""
  public var macIP: String = ""  // Empty means use global

  enum CodingKeys: String, CodingKey {
    case id, mainRepoPath, remoteWorktreePath, branch, syncInterval, hotReloadCommand,
      triggerOnChanges, worktreeRemoteName, macUser, macPath, macIP
  }

  public init(
    id: UUID = UUID(), mainRepoPath: String, remoteWorktreePath: String, branch: String,
    syncInterval: Int, hotReloadCommand: String, triggerOnChanges: Bool, worktreeRemoteName: String,
    macUser: String, macPath: String, macIP: String
  ) {
    self.id = id
    self.mainRepoPath = mainRepoPath
    self.remoteWorktreePath = remoteWorktreePath
    self.branch = branch
    self.syncInterval = syncInterval
    self.hotReloadCommand = hotReloadCommand
    self.triggerOnChanges = triggerOnChanges
    self.worktreeRemoteName = worktreeRemoteName
    self.macUser = macUser
    self.macPath = macPath
    self.macIP = macIP
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    mainRepoPath = try container.decodeIfPresent(String.self, forKey: .mainRepoPath) ?? ""
    remoteWorktreePath =
      try container.decodeIfPresent(String.self, forKey: .remoteWorktreePath) ?? ""
    branch = try container.decode(String.self, forKey: .branch)
    syncInterval = try container.decode(Int.self, forKey: .syncInterval)
    hotReloadCommand = try container.decode(String.self, forKey: .hotReloadCommand)
    triggerOnChanges = try container.decode(Bool.self, forKey: .triggerOnChanges)
    worktreeRemoteName =
      try container.decodeIfPresent(String.self, forKey: .worktreeRemoteName) ?? "local-dev"
    macUser = try container.decodeIfPresent(String.self, forKey: .macUser) ?? NSUserName()
    macPath = try container.decodeIfPresent(String.self, forKey: .macPath) ?? ""
    macIP = try container.decodeIfPresent(String.self, forKey: .macIP) ?? ""
  }
}

public struct SyncConfiguration: Codable, Equatable {
  public var localIP: String
  public var services: [SyncService]

  public init(localIP: String, services: [SyncService]) {
    self.localIP = localIP
    self.services = services
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
  public var syncConfig: SyncConfiguration?

  public init(id: UUID = UUID(), name: String, ipAddress: String, username: String, keyPath: String, environment: String = "Docker", savedLayouts: [PortLayout] = [], customPorts: [CustomPortMapping] = [], syncConfig: SyncConfiguration? = nil) {
    self.id = id
    self.name = name
    self.ipAddress = ipAddress
    self.username = username
    self.keyPath = keyPath
    self.environment = environment
    self.savedLayouts = savedLayouts
    self.customPorts = customPorts
    self.syncConfig = syncConfig
  }
}
