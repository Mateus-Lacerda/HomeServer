import Foundation

public enum SyncState: Equatable {
  case idle
  case syncing
  case success
  case failed(String)
}

public struct SyncLogEntry: Identifiable, Equatable {
  public let id = UUID()
  public let command: String
  public let stdout: String?
  public let stderr: String?
  public let exitCode: Int?
  public let timestamp: Date

  public var isSuccess: Bool {
    exitCode == 0
  }
}

public struct ServiceStatus: Equatable {
  public var state: SyncState = .idle
  public var lastSync: Date?
  public var log: [SyncLogEntry] = []

  public var lastMessage: String? {
    log.last?.stderr ?? log.last?.stdout
  }
}
