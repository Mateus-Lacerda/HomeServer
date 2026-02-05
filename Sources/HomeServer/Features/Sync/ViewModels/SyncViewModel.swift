import Foundation
import SwiftUI

@MainActor
class SyncViewModel: ObservableObject {
  @Published var localIP: String = ""
  @Published var editingService: SyncService?
  @Published var showingEditor = false
  @Published var isAuthorizing = false
  @Published var authStatus: String?
  @Published var availableUsers: [String] = []
  
  // Editor State
  @Published var ed_mainRepoPath = ""
  @Published var ed_remoteWorktreePath = ""
  @Published var ed_branch = "main"
  @Published var ed_interval = "0"
  @Published var ed_cmd = ""
  @Published var ed_trigger = false
  @Published var ed_worktreeRemoteName = "local-dev"
  @Published var ed_macUser = NSUserName()
  @Published var ed_macPath = ""
  @Published var ed_macIP = ""

  // Worktree setup states
  @Published var showingSetupLog = false
  @Published var setupLog: [SyncLogEntry] = []
  @Published var isSettingUpWorktree = false
    
  private var sessionService: SessionService
  private var syncManager: SyncManager
  
  // Callbacks for browser interaction
  var requestBrowser: ((BrowserMode, String, @escaping (String) -> Void) -> Void)?

  enum BrowserMode {
    case repo
    case sshKey
  }
    
  init(sessionService: SessionService, syncManager: SyncManager) {
    self.sessionService = sessionService
    self.syncManager = syncManager
    loadUsers()
  }
    
  func initialize(session: SavedSession) {
      if let config = session.syncConfig {
        localIP = config.localIP
      } else {
        localIP = "192.168.1.X"
      }
  }

  func loadUsers() {
    do {
      let users = try FileManager.default.contentsOfDirectory(atPath: "/Users")
      availableUsers = users.filter { !$0.hasPrefix(".") && $0 != "Shared" }
    } catch {
      print("Failed to load users: \(error)")
    }
  }

  func chooseLocalFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      ed_macPath = url.path
    }
  }

  func resetEditor() {
    ed_mainRepoPath = ""
    ed_remoteWorktreePath = ""
    ed_branch = "main"
    ed_interval = "0"
    ed_cmd = ""
    ed_trigger = false
    ed_worktreeRemoteName = "local-dev"
    ed_macUser = NSUserName()
    ed_macPath = ""
    ed_macIP = ""
  }

  func loadEditor(_ service: SyncService) {
    ed_mainRepoPath = service.mainRepoPath
    ed_remoteWorktreePath = service.remoteWorktreePath
    ed_branch = service.branch
    ed_interval = String(service.syncInterval)
    ed_cmd = service.hotReloadCommand
    ed_trigger = service.triggerOnChanges
    ed_worktreeRemoteName = service.worktreeRemoteName
    ed_macUser = service.macUser
    ed_macPath = service.macPath
    ed_macIP = service.macIP
  }

  func saveService(session: inout SavedSession) {
    let newService = SyncService(
      id: editingService?.id ?? UUID(),
      mainRepoPath: ed_mainRepoPath,
      remoteWorktreePath: ed_remoteWorktreePath,
      branch: ed_branch,
      syncInterval: Int(ed_interval) ?? 0,
      hotReloadCommand: ed_cmd,
      triggerOnChanges: ed_trigger,
      worktreeRemoteName: ed_worktreeRemoteName.isEmpty ? "local-dev" : ed_worktreeRemoteName,
      macUser: ed_macUser,
      macPath: ed_macPath,
      macIP: ed_macIP
    )

    var currentServices = session.syncConfig?.services ?? []

    if let editing = editingService,
      let idx = currentServices.firstIndex(where: { $0.id == editing.id })
    {
      currentServices[idx] = newService
    } else {
      currentServices.append(newService)
    }

    updateConfig(session: &session, ip: localIP, services: currentServices)
  }

  func deleteService(session: inout SavedSession, id: UUID) {
    var currentServices = session.syncConfig?.services ?? []
    currentServices.removeAll { $0.id == id }
    updateConfig(session: &session, ip: localIP, services: currentServices)
  }

  func save(session: inout SavedSession) {
    updateConfig(session: &session, ip: localIP, services: session.syncConfig?.services ?? [])
  }

  private func updateConfig(session: inout SavedSession, ip: String, services: [SyncService]) {
    let newConfig = SyncConfiguration(localIP: ip, services: services)
    session.syncConfig = newConfig
    sessionService.save(session: session)
  }

  func setupRemoteWorktree() {
    guard let service = editingService else { return }  // Use a temporary service or the current one being edited
    isSettingUpWorktree = true
    setupLog = []  // Clear previous log
    showingSetupLog = true  // Show log sheet immediately

    Task {
      let logs = await syncManager.setupWorktree(service: service)
      await MainActor.run {
        self.setupLog = logs
        self.isSettingUpWorktree = false
      }
    }
  }

  func setupRemoteAuth(session: SavedSession) {
    requestBrowser?(.sshKey, "/home/\(session.username)/.ssh") { [weak self] path in
        self?.authorizeKey(session: session, path: path)
    }
  }
    
  func openBrowserForRepo(session: SavedSession, path: String, onSelect: @escaping (String) -> Void) {
      let startPath = path.isEmpty ? "/home/\(session.username)" : path
      requestBrowser?(.repo, startPath, onSelect)
  }

  private func authorizeKey(session: SavedSession, path: String) {
    isAuthorizing = true
    authStatus = "Reading remote key..."
    Task {
      do {
        let keyContent = try await SSHService.readRemoteFile(
          ip: session.ipAddress,
          user: session.username,
          keyPath: session.keyPath,
          path: path
        )

        try SSHService.addKeyToLocalAuthorizedKeys(
          key: keyContent.trimmingCharacters(in: .whitespacesAndNewlines))

        await MainActor.run {
          self.authStatus = "Success! Key added to local authorized_keys."
          self.isAuthorizing = false
        }
      } catch {
        await MainActor.run {
          self.authStatus = "Error: \(error.localizedDescription)"
          self.isAuthorizing = false
        }
      }
    }
  }
}
