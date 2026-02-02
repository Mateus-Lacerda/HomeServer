import HomeServer
import SwiftUI

// MARK: - Local Helper
private func addKeyToLocalAuthorizedKeys(key: String) throws {
  let fileManager = FileManager.default
  let home = fileManager.homeDirectoryForCurrentUser
  let sshDir = home.appendingPathComponent(".ssh")

  if !fileManager.fileExists(atPath: sshDir.path) {
    try fileManager.createDirectory(
      at: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  }

  let authKeys = sshDir.appendingPathComponent("authorized_keys")

  if !fileManager.fileExists(atPath: authKeys.path) {
    try "".write(to: authKeys, atomically: true, encoding: .utf8)
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authKeys.path)
  }

  let fileHandle = try FileHandle(forWritingTo: authKeys)
  fileHandle.seekToEndOfFile()
  if let data = "\n\(key)\n".data(using: .utf8) {
    fileHandle.write(data)
  }
  try fileHandle.close()
}

// MARK: - Remote File Browser
struct RemoteFileBrowserView: View {
  let session: SavedSession
  @Binding var currentPath: String
  let onSelect: (String) -> Void
  let onCancel: () -> Void

  @State private var files: [String] = []
  @State private var isLoading = false
  @State private var error: String?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Remote Browser").font(.headline)
        Spacer()
        Button(action: onCancel) {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()
      .background(.ultraThinMaterial)

      HStack {
        Text(currentPath.isEmpty ? "/" : currentPath)
          .font(.caption.monospaced())
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(8)
          .background(Color.primary.opacity(0.05))
          .cornerRadius(6)

        if currentPath != "/" && !currentPath.isEmpty {
          Button(action: goUp) { Image(systemName: "arrow.up.folder") }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 8)

      if isLoading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = error {
        Text(error).foregroundColor(.red).padding()
        Button("Retry") { loadFiles() }
      } else {
        List {
          ForEach(files, id: \.self) { file in
            HStack {
              Image(systemName: file.hasSuffix("/") ? "folder.fill" : "doc")
                .foregroundStyle(file.hasSuffix("/") ? .blue : .secondary)
              Text(file)
              Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
              if file.hasSuffix("/") {
                navigate(to: file)
              } else {
                onSelect(fullPath(for: file))
              }
            }
          }
        }
        .listStyle(.plain)
      }

      HStack {
        Button("Select Current Folder") { onSelect(currentPath) }
          .disabled(currentPath.isEmpty)
        Spacer()
      }
      .padding()
      .background(.ultraThinMaterial)
    }
    .onAppear(perform: loadFiles)
  }

  private func fullPath(for file: String) -> String {
    let cleanPath = currentPath.hasSuffix("/") ? currentPath : currentPath + "/"
    return cleanPath + file
  }

  private func navigate(to dir: String) {
    let cleanPath = currentPath.hasSuffix("/") ? currentPath : currentPath + "/"
    currentPath = cleanPath + dir
    loadFiles()
  }

  private func goUp() {
    let components = currentPath.split(separator: "/").dropLast()
    currentPath = "/" + components.joined(separator: "/")
    if !currentPath.hasSuffix("/") { currentPath += "/" }
    loadFiles()
  }

  private func loadFiles() {
    isLoading = true
    error = nil
    Task {
      do {
        let list = try await SSHService.listDirectory(
          ip: session.ipAddress,
          user: session.username,
          keyPath: session.keyPath,
          path: currentPath.isEmpty ? "/" : currentPath
        )
        await MainActor.run {
          self.files = list.sorted {
            if $0.hasSuffix("/") && !$1.hasSuffix("/") { return true }
            if !$0.hasSuffix("/") && $1.hasSuffix("/") { return false }
            return $0 < $1
          }
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.error = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
}

// MARK: - Sync View
struct SyncView: View {
  @Binding var session: SavedSession
  @ObservedObject var syncManager: SyncManager
  @EnvironmentObject var sessionService: SessionService
  @Environment(\.dismiss) var dismiss

  @State private var selectedTab: Int = 0

  // Shared State for Browser (kept here to be passed down)
  @State private var showingBrowser = false
  @State private var browserMode: BrowserMode = .repo
  @State private var browserPath: String = ""
  @State private var onBrowserSelect: ((String) -> Void)?

  enum BrowserMode {
    case repo
    case sshKey
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Picker("", selection: $selectedTab) {
          Text("Monitor").tag(0)
          Text("Settings").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)

        Spacer()

        Button("Done") { dismiss() }
          .buttonStyle(.bordered)
      }
      .padding()
      .background(.ultraThinMaterial)

      if selectedTab == 0 {
        MonitorView(session: session, syncManager: syncManager)
      } else {
        SettingsView(
          session: $session,
          syncManager: syncManager,  // Pass syncManager down
          showingBrowser: $showingBrowser,
          browserMode: $browserMode,
          browserPath: $browserPath,
          onBrowserSelect: $onBrowserSelect
        )
      }
    }
    .sheet(isPresented: $showingBrowser) {
      RemoteFileBrowserView(
        session: session,
        currentPath: $browserPath,
        onSelect: { path in
          onBrowserSelect?(path)
          showingBrowser = false
        },
        onCancel: { showingBrowser = false }
      )
      .frame(width: 500, height: 400)
    }
  }
}

// MARK: - Monitor View
struct MonitorView: View {
  let session: SavedSession
  @ObservedObject var syncManager: SyncManager

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        if let config = session.syncConfig, !config.services.isEmpty {
          ForEach(config.services) { service in
            SyncStatusRow(
              service: service, status: syncManager.statuses[service.id] ?? ServiceStatus()
            ) {
              syncManager.forceSync(serviceId: service.id)
            }
          }
        } else {
          VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No services configured")
              .foregroundStyle(.secondary)
            Text("Go to Settings to add repositories.")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          .padding(.top, 40)
          .frame(maxWidth: .infinity)
        }
      }
      .padding()
    }
  }
}

struct SyncStatusRow: View {
  let service: SyncService
  let status: ServiceStatus
  let onSync: () -> Void

  @State private var showDetails = false

  var statusIcon: String {
    switch status.state {
    case .idle: return "clock"
    case .syncing: return "arrow.triangle.2.circlepath"
    case .success: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.triangle.fill"
    }
  }

  var statusColor: Color {
    switch status.state {
    case .idle: return .secondary
    case .syncing: return .blue
    case .success: return .green
    case .failed: return .red
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(URL(fileURLWithPath: service.mainRepoPath).lastPathComponent)  // Updated to mainRepoPath
          .font(.headline)
        Text(service.mainRepoPath)  // Updated to mainRepoPath
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        HStack {
          if status.state == .syncing {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: statusIcon)
              .foregroundStyle(statusColor)
          }

          Text(
            status.state == .syncing
              ? "Syncing..."
              : (status.state == .idle
                ? "Idle" : (status.state == .failed("") ? "Failed" : "Synced"))
          )
          .font(.subheadline)
          .foregroundStyle(statusColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
          if let msg = status.lastMessage, !msg.isEmpty {
            showDetails = true
          }
        }
        .popover(isPresented: $showDetails) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Sync Details").font(.headline)
            if status.log.isEmpty {
              Text("No detailed log available.")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              ScrollView {
                ForEach(status.log) { entry in
                  VStack(alignment: .leading, spacing: 5) {
                    HStack {
                      Text("> \(entry.command)")
                        .font(.caption.monospaced())
                        .fontWeight(.bold)
                        .foregroundStyle(entry.isSuccess ? .blue : .red)
                      Spacer()
                      Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    if let stdout = entry.stdout, !stdout.isEmpty {
                      Text(stdout)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.primary)
                    }
                    if let stderr = entry.stderr, !stderr.isEmpty {
                      Text(stderr)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.red)
                    }
                  }
                  .padding(.bottom, 5)
                }
              }
            }
          }
          .padding()
          .frame(width: 400, height: 300)
        }

        if let lastSync = status.lastSync {
          Text(lastSync, style: .time)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Button(action: onSync) {
        Image(systemName: "arrow.clockwise")
          .padding(8)
          .background(Color.primary.opacity(0.05))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(status.state == .syncing)
      .padding(.leading, 8)
    }
    .padding()
    .background(Color.primary.opacity(0.02))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(statusColor.opacity(0.3), lineWidth: 1)
    )
  }
}

// MARK: - Settings View
struct SettingsView: View {
  @Binding var session: SavedSession
  @EnvironmentObject var sessionService: SessionService
  @ObservedObject var syncManager: SyncManager  // Pass syncManager down

  @Binding var showingBrowser: Bool
  @Binding var browserMode: SyncView.BrowserMode
  @Binding var browserPath: String
  @Binding var onBrowserSelect: ((String) -> Void)?

  @State private var localIP: String = ""
  @State private var editingService: SyncService?
  @State private var showingEditor = false
  @State private var isAuthorizing = false
  @State private var authStatus: String?

  // Editor State
  @State private var ed_mainRepoPath = ""
  @State private var ed_remoteWorktreePath = ""
  @State private var ed_branch = "main"
  @State private var ed_interval = "0"
  @State private var ed_cmd = ""
  @State private var ed_trigger = false
  @State private var ed_worktreeRemoteName = "local-dev"
  @State private var ed_macUser = NSUserName()
  @State private var ed_macPath = ""
  @State private var ed_macIP = ""
  @State private var availableUsers: [String] = []

  // Worktree setup states
  @State private var showingSetupLog = false
  @State private var setupLog: [SyncLogEntry] = []
  @State private var isSettingUpWorktree = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // 1. General Config
        VStack(alignment: .leading, spacing: 10) {
          Text("General").font(.subheadline).foregroundStyle(.secondary)
          GlassTextField(icon: "network", title: "Local IP Address", text: $localIP)
            .onChange(of: localIP) { _, _ in save() }

          Button(action: setupRemoteAuth) {
            HStack {
              if isAuthorizing { ProgressView().controlSize(.small) }
              Text("Setup Remote Auth Key")
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
          }
          .disabled(isAuthorizing)

          if let status = authStatus {
            Text(status).font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)

        // 2. Services
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Synced Services").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button(action: {
              editingService = nil
              resetEditor()
              showingEditor = true
            }) {
              Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.plain)
          }

          if let config = session.syncConfig, !config.services.isEmpty {
            ForEach(config.services) { service in
              ServiceRow(service: service) {
                editingService = service
                loadEditor(service)
                showingEditor = true
              }
              .contextMenu {
                Button("Delete", role: .destructive) {
                  deleteService(service.id)
                }
              }
            }
          } else {
            Text("No services configured.").font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
      }
      .padding()
    }
    .onAppear {
      if let config = session.syncConfig {
        localIP = config.localIP
      } else {
        localIP = "192.168.1.X"
      }
      loadUsers()
    }
    .sheet(isPresented: $showingEditor) {
      VStack(spacing: 20) {
        Text(editingService == nil ? "Add Service" : "Edit Service").font(.headline)

        ScrollView {
          VStack(alignment: .leading, spacing: 15) {
            Group {
              Text("Remote (Server) Worktree Config").font(.caption.bold()).foregroundStyle(
                .secondary)
              HStack {
                GlassTextField(
                  icon: "archivebox", title: "Main Repo Path (Remote)", text: $ed_mainRepoPath)
                Button(action: {
                  browserMode = .repo
                  browserPath = "/home/\(session.username)"
                  onBrowserSelect = { path in ed_mainRepoPath = path }
                  showingBrowser = true
                }) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              HStack {
                GlassTextField(
                  icon: "folder", title: "Worktree Path (Remote)", text: $ed_remoteWorktreePath)
                Button(action: {
                  browserMode = .repo
                  browserPath =
                    ed_mainRepoPath.isEmpty
                    ? "/home/\(session.username)"
                    : (URL(fileURLWithPath: ed_mainRepoPath).deletingLastPathComponent().path)
                  onBrowserSelect = { path in ed_remoteWorktreePath = path }
                  showingBrowser = true
                }) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              GlassTextField(
                icon: "network.badge.shield.half.filled", title: "Worktree Remote Name (local-dev)",
                text: $ed_worktreeRemoteName)
              GlassTextField(icon: "arrow.branch", title: "Branch", text: $ed_branch)
              GlassTextField(icon: "timer", title: "Sync Interval (sec)", text: $ed_interval)
              GlassTextField(icon: "terminal", title: "Hot Reload Command", text: $ed_cmd)
              Toggle("Trigger on changes", isOn: $ed_trigger)

              Button(action: setupRemoteWorktree) {
                HStack {
                  if isSettingUpWorktree { ProgressView().controlSize(.small) }
                  Text("Setup Worktree on Remote")
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
              }
              .disabled(
                isSettingUpWorktree || ed_mainRepoPath.isEmpty || ed_remoteWorktreePath.isEmpty
                  || ed_branch.isEmpty || ed_worktreeRemoteName.isEmpty || ed_macUser.isEmpty
                  || ed_macPath.isEmpty)
            }

            Divider().padding(.vertical, 5)

            Group {
              Text("Local (Mac) Source Config").font(.caption.bold()).foregroundStyle(.secondary)

              VStack(alignment: .leading, spacing: 6) {
                Label("Mac User", systemImage: "person").font(.caption).foregroundStyle(.secondary)
                Menu {
                  ForEach(availableUsers, id: \.self) { user in
                    Button(user) { ed_macUser = user }
                  }
                } label: {
                  HStack {
                    Text(ed_macUser.isEmpty ? "Select User" : ed_macUser)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                  }
                  .padding(10)
                  .background(Color.primary.opacity(0.05))
                  .cornerRadius(8)
                }
                .menuStyle(.borderlessButton)
              }

              HStack {
                GlassTextField(icon: "laptopcomputer", title: "Local Repo Path", text: $ed_macPath)
                Button(action: chooseLocalFolder) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              GlassTextField(icon: "network", title: "Mac IP Override (Optional)", text: $ed_macIP)
            }
          }
          .padding()
        }

        HStack {
          Button("Cancel") { showingEditor = false }
          Button("Save") {
            saveService()
            showingEditor = false
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding()
      .frame(width: 450, height: 750)  // Increased height for new fields
    }
    .sheet(isPresented: $showingSetupLog) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Worktree Setup Log").font(.headline)
        if setupLog.isEmpty && isSettingUpWorktree {
          ProgressView("Setting up worktree...")
        } else if setupLog.isEmpty {
          Text("No log available.")
        } else {
          ScrollView {
            ForEach(setupLog) { entry in
              VStack(alignment: .leading, spacing: 5) {
                HStack {
                  Text("> \(entry.command)")
                    .font(.caption.monospaced())
                    .fontWeight(.bold)
                    .foregroundStyle(entry.isSuccess ? .blue : .red)
                  Spacer()
                  Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if let stdout = entry.stdout, !stdout.isEmpty {
                  Text(stdout)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
                }
                if let stderr = entry.stderr, !stderr.isEmpty {
                  Text(stderr)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.red)
                }
              }
              .padding(.bottom, 5)
            }
          }
        }
        Button("Done") { showingSetupLog = false }.buttonStyle(.borderedProminent)
      }
      .padding()
      .frame(width: 600, height: 400)
    }
  }

  private func loadUsers() {
    do {
      let users = try FileManager.default.contentsOfDirectory(atPath: "/Users")
      availableUsers = users.filter { !$0.hasPrefix(".") && $0 != "Shared" }
    } catch {
      print("Failed to load users: \(error)")
    }
  }

  private func chooseLocalFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      ed_macPath = url.path
    }
  }

  private func resetEditor() {
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

  private func loadEditor(_ service: SyncService) {
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

  private func saveService() {
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

    updateConfig(ip: localIP, services: currentServices)
  }

  private func deleteService(_ id: UUID) {
    var currentServices = session.syncConfig?.services ?? []
    currentServices.removeAll { $0.id == id }
    updateConfig(ip: localIP, services: currentServices)
  }

  private func save() {
    updateConfig(ip: localIP, services: session.syncConfig?.services ?? [])
  }

  private func updateConfig(ip: String, services: [SyncService]) {
    let newConfig = SyncConfiguration(localIP: ip, services: services)
    session.syncConfig = newConfig
    sessionService.save(session: session)
  }

  // Worktree setup states
  // @State private var showingSetupLog = false // Moved to top
  // @State private var setupLog: [SyncLogEntry] = [] // Moved to top
  // @State private var isSettingUpWorktree = false // Moved to top

  private func setupRemoteWorktree() {
    guard let service = editingService else { return }  // Use a temporary service or the current one being edited
    isSettingUpWorktree = true
    setupLog = []  // Clear previous log
    showingSetupLog = true  // Show log sheet immediately

    Task {
      let logs = await syncManager.setupWorktree(service: service)
      await MainActor.run {
        setupLog = logs
        isSettingUpWorktree = false
      }
    }
  }

  private func setupRemoteAuth() {
    browserMode = .sshKey
    browserPath = "/home/\(session.username)/.ssh"
    onBrowserSelect = { path in authorizeKey(path: path) }
    showingBrowser = true
  }

  private func authorizeKey(path: String) {
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

        try addKeyToLocalAuthorizedKeys(
          key: keyContent.trimmingCharacters(in: .whitespacesAndNewlines))

        await MainActor.run {
          authStatus = "Success! Key added to local authorized_keys."
          isAuthorizing = false
        }
      } catch {
        await MainActor.run {
          authStatus = "Error: \(error.localizedDescription)"
          isAuthorizing = false
        }
      }
    }
  }
}

struct ServiceRow: View {
  let service: SyncService
  let onTap: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(URL(fileURLWithPath: service.mainRepoPath).lastPathComponent)
          .font(.headline)
        Text(service.mainRepoPath)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing) {
        Text(service.branch).font(.monospaced(.caption)())
          .padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
        if service.syncInterval > 0 {
          Text("Auto: \(service.syncInterval)s").font(.caption).foregroundStyle(.green)
        }
      }
    }
    .padding()
    .background(Color.primary.opacity(0.02))
    .cornerRadius(8)
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
  }
}
