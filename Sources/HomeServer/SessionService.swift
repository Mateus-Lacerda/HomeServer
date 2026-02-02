import Foundation

struct PortLayout: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var name: String
  var mappings: [Int: Int]  // Key: Remote Port, Value: Local Port
}

struct CustomPortMapping: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var name: String
  var remotePort: Int
  var localPort: Int
}

public struct SyncService: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID = UUID()
  var mainRepoPath: String = ""  // Path to the main .git repo on the remote
  var remoteWorktreePath: String = ""  // Path to the worktree folder on the remote
  var branch: String = "main"
  var syncInterval: Int = 0  // 0 for manual
  var hotReloadCommand: String = ""
  var triggerOnChanges: Bool = false
  var worktreeRemoteName: String = "local-dev"  // Name of the remote on the worktree
  var macUser: String = NSUserName()
  var macPath: String = ""
  var macIP: String = ""  // Empty means use global

  enum CodingKeys: String, CodingKey {
    case id, mainRepoPath, remoteWorktreePath, branch, syncInterval, hotReloadCommand,
      triggerOnChanges, worktreeRemoteName, macUser, macPath, macIP
  }

  init(
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

struct SyncConfiguration: Codable, Equatable {
  var localIP: String
  var services: [SyncService]
}

public struct SavedSession: Identifiable, Codable, Equatable {
  public var id: UUID = UUID()
  var name: String
  var ipAddress: String
  var username: String
  var keyPath: String
  var environment: String = "Docker"
  var savedLayouts: [PortLayout] = []
  var customPorts: [CustomPortMapping] = []
  var syncConfig: SyncConfiguration?
}

class SessionService: ObservableObject {
  @Published var sessions: [SavedSession] = []

  private let fileURL: URL

  init() {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".homeserver")

    do {
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      print("CRITICAL ERROR: Could not create config directory at \(dir.path): \(error)")
    }

    self.fileURL = dir.appendingPathComponent("sessions.json")
    print("Storage Path: \(self.fileURL.path)")

    load()
  }

  func load() {
    do {
      let data = try Data(contentsOf: fileURL)
      sessions = try JSONDecoder().decode([SavedSession].self, from: data)
      print("Loaded \(sessions.count) sessions from disk.")
    } catch {
      print("No existing sessions loaded (or decode failed): \(error)")
      sessions = []
    }
  }

  func save(session: SavedSession) {
    if let index = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[index] = session
    } else {
      sessions.append(session)
    }
    persist()
  }

  func delete(id: UUID) {
    sessions.removeAll { $0.id == id }
    persist()
  }

  private func persist() {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(sessions)
      try data.write(to: fileURL)
      print("Successfully saved sessions to \(fileURL.path)")
    } catch {
      print("Failed to save sessions: \(error)")
    }
  }
}
