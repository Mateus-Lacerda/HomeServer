import Foundation
import SwiftUI

@MainActor
class ConnectionViewModel: ObservableObject {
  @Published var name: String = ""
  @Published var ipAddress: String = ""
  @Published var username: String = ""
  @Published var selectedKeyPath: String = ""
  @Published var environment: String = "Docker"
  @Published var availableKeys: [String] = []
  @Published var isConnecting: Bool = false
  @Published var error: String?

  private var id: UUID
  private var sessionService: SessionService
  
  // Callbacks
  var onConnect: ((SavedSession) -> Void)?
  var onCancel: (() -> Void)?

  init(session: SavedSession?, sessionService: SessionService, onConnect: @escaping (SavedSession) -> Void, onCancel: (() -> Void)?) {
    self.sessionService = sessionService
    self.onConnect = onConnect
    self.onCancel = onCancel
    
    if let session = session {
      self.id = session.id
      self.name = session.name
      self.ipAddress = session.ipAddress
      self.username = session.username
      self.selectedKeyPath = session.keyPath
      self.environment = session.environment
    } else {
      self.id = UUID()
    }
  }

  func loadSSHKeys() {
    let fileManager = FileManager.default
    let sshPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
    availableKeys =
      (try? fileManager.contentsOfDirectory(at: sshPath, includingPropertiesForKeys: nil))?
      .compactMap { url in
        let name = url.lastPathComponent
        return (name.hasSuffix(".pub") || name == "known_hosts" || name == "config")
          ? nil : url.path
      } ?? []
  }

  func save() -> SavedSession {
    let existing = sessionService.sessions.first(where: { $0.id == id })
    let session = SavedSession(
      id: id, name: name, ipAddress: ipAddress, username: username, keyPath: selectedKeyPath,
      environment: environment, savedLayouts: existing?.savedLayouts ?? [],
      customPorts: existing?.customPorts ?? [])
    sessionService.save(session: session)
    return session
  }

  func connect() {
    isConnecting = true
    let session = save()
    Task {
      let result = await SSHService.testConnection(
        ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
      await MainActor.run {
        isConnecting = false
        if case .success = result {
            onConnect?(session)
        } else {
            // Handle error or debug
            SSHService.openTerminalForDebugging(
            ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
        }
      }
    }
  }
}
