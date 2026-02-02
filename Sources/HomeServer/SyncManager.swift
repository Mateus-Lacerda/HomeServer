import Combine
import Foundation

@MainActor
public class SyncManager: ObservableObject {
  @Published public var statuses: [UUID: ServiceStatus] = [:]

  private var timers: [UUID: Timer] = [:]
  private var currentSession: SavedSession?  // Renamed to avoid confusion with `session` parameter in methods

  public init() {}  // Explicit init

  public func update(session: SavedSession) {
    self.currentSession = session
    stopAll()
    startAll()
  }

  public func stopAll() {
    timers.values.forEach { $0.invalidate() }
    timers.removeAll()
  }

  public func forceSync(serviceId: UUID) {
    guard let session = currentSession, let config = session.syncConfig,
      let service = config.services.first(where: { $0.id == serviceId })
    else { return }

    Task {
      await self.sync(service: service)
    }
  }

  private func startAll() {
    guard let session = currentSession, let config = session.syncConfig else { return }

    // Initialize statuses for new services if needed
    for service in config.services {
      if statuses[service.id] == nil {
        statuses[service.id] = ServiceStatus()
      }
    }

    for service in config.services {
      if service.syncInterval > 0 {
        let timer = Timer.scheduledTimer(
          withTimeInterval: TimeInterval(service.syncInterval), repeats: true
        ) { [weak self] _ in
          Task {
            guard let self = self else { return }
            await self.sync(service: service)
          }
        }
        timers[service.id] = timer
      }
    }
  }

  // Helper to run a command and log its output, updating internal state
  private func runAndLog(
    service: SyncService, command: String, description: String, workingDir: String? = nil,
    tempLog: inout [SyncLogEntry], overallSuccess: inout Bool, errorMessage: inout String?
  ) async -> Bool {
    guard let session = currentSession else {
      errorMessage = "Session is nil."
      overallSuccess = false
      return false
    }
    let fullCommand = if let dir = workingDir { "cd \"\(dir)\" && \(command)" } else { command }
    do {
      let commandOutput = try await SSHService.runCommandDetailed(
        ip: session.ipAddress,
        user: session.username,
        keyPath: session.keyPath,
        command: fullCommand
      )
      let logEntry = SyncLogEntry(
        command: description,
        stdout: commandOutput.stdout,
        stderr: commandOutput.stderr,
        exitCode: commandOutput.exitCode,
        timestamp: Date()
      )
      tempLog.append(logEntry)

      if commandOutput.exitCode != 0 {
        overallSuccess = false
        errorMessage =
          commandOutput.stderr ?? commandOutput.stdout ?? "Unknown error during '\(description)'"
        return false
      }
      return true
    } catch {
      overallSuccess = false
      errorMessage = error.localizedDescription
      let logEntry = SyncLogEntry(
        command: description,
        stdout: nil,
        stderr: error.localizedDescription,
        exitCode: nil,
        timestamp: Date()
      )
      tempLog.append(logEntry)
      return false
    }
  }

  public func setupWorktree(service: SyncService) async -> [SyncLogEntry] {
    var tempLog: [SyncLogEntry] = []
    var overallSuccess = true
    var errorMessage: String? = nil  // Not used in return, but for runAndLog

    // 1. Prepare the Main Repository
    if !(await self.runAndLog(
      service: service, command: "git config extensions.worktreeConfig true",
      description: "Config worktreeConfig", workingDir: service.mainRepoPath, tempLog: &tempLog,
      overallSuccess: &overallSuccess, errorMessage: &errorMessage))
    {
      return tempLog
    }

    // 2. Create the Worktree of Synchronization
    // Check if worktree already exists before adding
    let checkWorktreeCommand =
      "git worktree list --porcelain | grep \"\(service.remoteWorktreePath)\""
    // Need to run checkOutput from mainRepoPath or global, as worktree list is a plumbing command
    let checkOutput = try? await SSHService.runCommandDetailed(
      ip: currentSession!.ipAddress, user: currentSession!.username,
      keyPath: currentSession!.keyPath,
      command: "cd \"\(service.mainRepoPath)\" && \(checkWorktreeCommand)")

    if checkOutput?.exitCode != 0 || (checkOutput?.stdout ?? "").isEmpty {  // Worktree does not exist
      let worktreeAddCommand =
        "git worktree add \"\(service.remoteWorktreePath)\" \"\(service.branch)\""
      if !(await self.runAndLog(
        service: service, command: worktreeAddCommand, description: "Add Worktree",
        workingDir: service.mainRepoPath, tempLog: &tempLog, overallSuccess: &overallSuccess,
        errorMessage: &errorMessage))
      {
        return tempLog
      }
    } else {
      _ = await self.runAndLog(
        service: service,
        command: "echo \"Worktree at \(service.remoteWorktreePath) already exists.\"",
        description: "Worktree Exists", workingDir: service.mainRepoPath, tempLog: &tempLog,
        overallSuccess: &overallSuccess, errorMessage: &errorMessage)
    }

    // 3. Configure the Remote exclusive in the Worktree
    let macIP =
      !service.macIP.isEmpty ? service.macIP : (currentSession?.syncConfig?.localIP ?? "127.0.0.1")
    let gitRemoteURL = "ssh://\(service.macUser)@\(macIP)\(service.macPath)"

    // Add remote
    // Check if remote already exists first
    let checkRemoteCommand = "git config --worktree --get remote.\(service.worktreeRemoteName).url"
    let remoteCheckOutput = try? await SSHService.runCommandDetailed(
      ip: currentSession!.ipAddress, user: currentSession!.username,
      keyPath: currentSession!.keyPath,
      command: "cd \"\(service.remoteWorktreePath)\" && \(checkRemoteCommand)")

    if remoteCheckOutput?.exitCode != 0
      || (remoteCheckOutput?.stdout ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        != gitRemoteURL
    {
      let addRemoteCommand =
        "git config --worktree remote.\(service.worktreeRemoteName).url \"\(gitRemoteURL)\""
      _ = await self.runAndLog(
        service: service, command: addRemoteCommand, description: "Add Worktree Remote",
        workingDir: service.remoteWorktreePath, tempLog: &tempLog, overallSuccess: &overallSuccess,
        errorMessage: &errorMessage)
    } else {
      _ = await self.runAndLog(
        service: service,
        command: "echo \"Remote \(service.worktreeRemoteName) already configured.\"",
        description: "Worktree Remote Exists", workingDir: service.remoteWorktreePath,
        tempLog: &tempLog, overallSuccess: &overallSuccess, errorMessage: &errorMessage)
    }

    // Configure branch tracking (optional, but good practice)
    let configBranchRemoteCommand =
      "git config --worktree branch.\(service.branch).remote \(service.worktreeRemoteName)"
    _ = await self.runAndLog(
      service: service, command: configBranchRemoteCommand, description: "Config Branch Remote",
      workingDir: service.remoteWorktreePath, tempLog: &tempLog, overallSuccess: &overallSuccess,
      errorMessage: &errorMessage)

    let configBranchMergeCommand =
      "git config --worktree branch.\(service.branch).merge refs/heads/\(service.branch)"
    _ = await self.runAndLog(
      service: service, command: configBranchMergeCommand, description: "Config Branch Merge",
      workingDir: service.remoteWorktreePath, tempLog: &tempLog, overallSuccess: &overallSuccess,
      errorMessage: &errorMessage)

    return tempLog
  }

  private func sync(service: SyncService) async {
    guard currentSession != nil else { return }

    // Update status to syncing
    var currentStatus = statuses[service.id] ?? ServiceStatus()
    currentStatus.state = .syncing
    currentStatus.log = []  // Clear previous log
    self.statuses[service.id] = currentStatus

    var tempLog: [SyncLogEntry] = []
    var overallSuccess = true
    var errorMessage: String? = nil

    // Navigate to the worktree directory
    let workingDir = service.remoteWorktreePath

    // 1. Fetch from Mac
    let fetchCommand = "git fetch \(service.worktreeRemoteName) \"\(service.branch)\""
    if !(await self.runAndLog(
      service: service, command: fetchCommand,
      description: "Fetch from \(service.worktreeRemoteName)", workingDir: workingDir,
      tempLog: &tempLog, overallSuccess: &overallSuccess, errorMessage: &errorMessage))
    {
      self.statuses[service.id]?.state = .failed(errorMessage ?? "Fetch failed.")
      self.statuses[service.id]?.log = tempLog
      self.statuses[service.id]?.lastSync = Date()
      return
    }

    // 1.5 Checkout to the correct branch
    let checkoutCommand = "git checkout -B \"\(service.branch)\" FETCH_HEAD"
    if !(await self.runAndLog(
      service: service, command: checkoutCommand, description: "Switch to Branch \(service.branch)",
      workingDir: workingDir, tempLog: &tempLog, overallSuccess: &overallSuccess,
      errorMessage: &errorMessage))
    {
      self.statuses[service.id]?.state = .failed(errorMessage ?? "Checkout failed.")
      self.statuses[service.id]?.log = tempLog
      self.statuses[service.id]?.lastSync = Date()
      return
    }

    // 2. Hard Reset to Mac's branch state (now relative to the newly checked out branch)
    let resetCommand = "git reset --hard FETCH_HEAD"
    if !(await self.runAndLog(
      service: service, command: resetCommand, description: "Hard Reset to Branch",
      workingDir: workingDir, tempLog: &tempLog, overallSuccess: &overallSuccess,
      errorMessage: &errorMessage))
    {
      self.statuses[service.id]?.state = .failed(errorMessage ?? "Reset failed.")
      self.statuses[service.id]?.log = tempLog
      self.statuses[service.id]?.lastSync = Date()
      return
    }

    // Check for changes after reset
    let lastResetLogEntry = tempLog.last(where: { $0.command.hasPrefix("Hard Reset to Branch") })
    let hasChanges = !(lastResetLogEntry?.stdout?.contains("Already up to date") ?? false)  // Simplified check

    // 3. Hot Reload if needed
    if hasChanges && service.triggerOnChanges && !service.hotReloadCommand.isEmpty {
      let hotReloadCmd = service.hotReloadCommand
      if !(await self.runAndLog(
        service: service, command: hotReloadCmd, description: "Hot Reload", workingDir: workingDir,
        tempLog: &tempLog, overallSuccess: &overallSuccess, errorMessage: &errorMessage))
      {
        overallSuccess = false  // Mark overall as failed due to reload failure
      }
    }

    // Final Status Update
    if overallSuccess {
      self.statuses[service.id]?.state = .success
    } else {
      self.statuses[service.id]?.state = .failed(
        errorMessage ?? "Sync process completed with errors.")
    }
    self.statuses[service.id]?.log = tempLog
    self.statuses[service.id]?.lastSync = Date()
  }
}
