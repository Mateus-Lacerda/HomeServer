import SwiftUI

@main
struct HomeServerApp: App {
  @StateObject private var sessionService = SessionService()

  init() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(sessionService)
    }
    .windowStyle(.hiddenTitleBar)
  }
}

// MARK: - Navigation Enum
enum AppState {
  case list
  case editor(session: SavedSession?)
  case connected(session: SavedSession)
}

// MARK: - Main Content View
struct ContentView: View {
  @EnvironmentObject var sessionService: SessionService
  @State private var appState: AppState = .list
  @State private var activeSession: SavedSession?
  @State private var editingSession: SavedSession?

  var body: some View {
    ZStack {
      VisualEffectView().ignoresSafeArea()
      // ConcentricBackground()

      Group {
        switch appState {
        case .list:
          if sessionService.sessions.isEmpty {
            ConnectionView(
              savedSession: nil,
              onConnect: { session in
                activeSession = session
                appState = .connected(session: session)
              }, onCancel: nil)
          } else {
            SessionListView(
              onSelect: { session in
                activeSession = session
                appState = .connected(session: session)
              },
              onEdit: { session in
                editingSession = session
                appState = .editor(session: session)
              },
              onNew: {
                editingSession = nil
                appState = .editor(session: nil)
              }
            )
          }

        case .editor(let session):
          ConnectionView(
            savedSession: session,
            onConnect: { newSession in
              activeSession = newSession
              appState = .connected(session: newSession)
            },
            onCancel: {
              appState = .list
            })

        case .connected(let session):
          PortMappingView(
            session: session,
            onDisconnect: {
              appState = .list
            }
          )
        }
      }
      // .frame(maxWidth: 800, maxHeight: 600)
      .padding()
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: "\(appState)")
  }
}

// MARK: - Visual Components

struct VisualEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.state = .active
    view.material = .underWindowBackground
    return view
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct GlassPowerButton: View {
  var action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .fill(.red.opacity(isHovering ? 0.5 : 0.3))
          .glassEffect()

        Image(systemName: "power")
          .font(.system(size: 14, weight: .black))
          .foregroundColor(.white)
          .shadow(color: .black.opacity(0.2), radius: 1)
      }
      .frame(width: 32, height: 32)
      .scaleEffect(isHovering ? 1.1 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }
}

struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct LiquidGlassModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial)
      .cornerRadius(18)
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
          )
      )
      .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
  }
}

extension View { func liquidGlass() -> some View { self.modifier(LiquidGlassModifier()) } }

struct ConcentricBackground: View {
  @State private var rotate = false
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black.opacity(0.8), Color.blue.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ).ignoresSafeArea()

      ForEach(0..<5) { i in
        Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
          .frame(width: 300 + CGFloat(i * 150), height: 300 + CGFloat(i * 150))
          .rotationEffect(.degrees(rotate ? 360 : 0))
          .animation(.linear(duration: 80).repeatForever(autoreverses: false), value: rotate)
      }
    }.onAppear { rotate = true }
  }
}

struct GlassTextField: View {
  let icon: String
  let title: String
  @Binding var text: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary).padding(
        .leading, 4)
      TextField("", text: $text).textFieldStyle(.plain).padding(10).background(
        Color.primary.opacity(0.05)
      ).cornerRadius(8)
    }
  }
}

// MARK: - Tunnel Manager
@MainActor
class TunnelManager: ObservableObject {
  @Published var isConnected = false
  @Published var isConnecting = false
  @Published var error: String?

  private var process: Process?
  private var askpassScriptURL: URL?

  var onTermination: (() -> Void)?

  func startTunnel(session: SavedSession, ports: [RemotePort], password: String?) async {
    isConnecting = true
    error = nil

    var args = [
      "-N", "-o", "StrictHostKeyChecking=accept-new", "-o", "ServerAliveInterval=15", "-o",
      "ExitOnForwardFailure=yes",
    ]

    if !session.keyPath.isEmpty, session.keyPath != "MANUAL" {
      args.append(contentsOf: ["-i", session.keyPath])
    }

    for port in ports {
      args.append(contentsOf: ["-L", "\(port.localPort):localhost:\(port.remotePort)"])
    }

    args.append("\(session.username)@\(session.ipAddress)")

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    task.arguments = args

    var env = ProcessInfo.processInfo.environment
    if let password = password, !password.isEmpty {
      let script = "#!/bin/sh\necho \"\(password)\"\n"
      let tempDir = FileManager.default.temporaryDirectory
      let scriptURL = tempDir.appendingPathComponent("ssh_askpass_\(UUID().uuidString).sh")
      self.askpassScriptURL = scriptURL

      do {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        env["SSH_ASKPASS"] = scriptURL.path
        env["DISPLAY"] = ":0"
        env["SSH_ASKPASS_REQUIRE"] = "force"
      } catch {
        self.error = "Failed to setup auth: \(error.localizedDescription)"
        self.isConnecting = false
        return
      }
    }
    task.environment = env

    let pipe = Pipe()
    task.standardError = pipe

    task.terminationHandler = { [weak self] proc in
      Task { @MainActor in
        self?.cleanup()
        self?.isConnected = false
        self?.isConnecting = false

        if proc.terminationStatus != 0 {
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown SSH error"
          self?.error = "Tunnel Error: \(errorMsg)"
        }

        self?.onTermination?()
      }
    }

    do {
      try task.run()
      self.process = task
      try await Task.sleep(nanoseconds: 500_000_000)
      if task.isRunning {
        self.isConnected = true
        self.isConnecting = false
      }
    } catch {
      self.error = "Failed to start SSH: \(error.localizedDescription)"
      self.isConnecting = false
      cleanup()
    }
  }

  func stopTunnel() {
    process?.terminate()
    cleanup()
    isConnected = false
  }

  private func cleanup() {
    process = nil
    if let url = askpassScriptURL {
      try? FileManager.default.removeItem(at: url)
      askpassScriptURL = nil
    }
  }
}

// MARK: - Session List View
struct SessionListView: View {
  @EnvironmentObject var sessionService: SessionService
  let onSelect: (SavedSession) -> Void
  let onEdit: (SavedSession) -> Void
  let onNew: () -> Void
  @State private var isHoveringPlus = false

  let cardWidth: CGFloat = 250

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        VStack(alignment: .leading) {
          Text("My Labs").font(.system(size: 32, weight: .light))
          Text("Select a server to connect").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button(action: onNew) {
          Image(systemName: "plus").font(.headline).padding(10)
            .background(
              Circle()
                .fill(Color.accentColor.opacity(isHoveringPlus ? 0.4 : 0.2))
            )
            .glassEffect(in: .circle)
            .overlay(
              Circle().stroke(Color.accentColor.opacity(isHoveringPlus ? 0.6 : 0.3), lineWidth: 1)
            )
            .scaleEffect(isHoveringPlus ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringPlus = $0 }
      }
      .padding(.horizontal, 20)

      ScrollView {
        LazyVGrid(
          columns: [
            GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: 20)
          ],
          alignment: .leading,
          spacing: 20
        ) {
          ForEach(sessionService.sessions) { session in
            SessionCard(
              session: session,
              onSelect: { onSelect(session) },
              onEdit: { onEdit(session) },
              onDelete: { sessionService.delete(id: session.id) }
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        Spacer(minLength: 0)
      }
    }
    .padding(.top, 30)
    .liquidGlass()
  }
}

struct SessionCard: View {
  let session: SavedSession
  let onSelect: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(alignment: .leading, spacing: 15) {
        HStack {
          Image(systemName: "server.rack")
            .font(.title2)
            .foregroundStyle(.secondary)
          Spacer()
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(session.name).font(.headline).lineLimit(1)
          Text(session.ipAddress).font(.caption).foregroundStyle(.secondary)
        }

        Button(action: onSelect) {
          HStack {
            Text("Connect")
            Spacer()
            Image(systemName: "arrow.right")
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(Color.accentColor.opacity(0.1))
          .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 8))
      }
      .padding(16)
      .background(.ultraThinMaterial)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.primary.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
      )

      Menu {
        Button("Edit", action: onEdit)
        Button("Delete", role: .destructive, action: onDelete)
      } label: {
        Image(systemName: "ellipsis")
          .rotationEffect(.degrees(90))
          .padding(10)
          .background(Color.primary.opacity(0.05))
          .clipShape(Circle())
      }
      .menuStyle(.borderlessButton)
      .padding(5)
    }
    .frame(width: 250, height: 150)
    .onHover { hover in
      withAnimation(.easeInOut(duration: 0.2)) { isHovering = hover }
    }
  }
}

struct ConnectionView: View {
  @EnvironmentObject var sessionService: SessionService
  @State private var id: UUID
  @State private var name: String = ""
  @State private var ipAddress: String = ""
  @State private var username: String = ""
  @State private var selectedKeyPath: String = ""
  @State private var environment: String = "Docker"
  @State private var availableKeys: [String] = []
  @State private var isConnecting: Bool = false
  let onConnect: (SavedSession) -> Void
  let onCancel: (() -> Void)?
  init(
    savedSession: SavedSession?, onConnect: @escaping (SavedSession) -> Void,
    onCancel: (() -> Void)?
  ) {
    self.onConnect = onConnect
    self.onCancel = onCancel
    if let session = savedSession {
      _id = State(initialValue: session.id)
      _name = State(initialValue: session.name)
      _ipAddress = State(initialValue: session.ipAddress)
      _username = State(initialValue: session.username)
      _selectedKeyPath = State(initialValue: session.keyPath)
      _environment = State(initialValue: session.environment)
    } else {
      _id = State(initialValue: UUID())
    }
  }
  var body: some View {
    VStack(spacing: 25) {
      HStack {
        Button(action: { onCancel?() }) {
          Image(systemName: "chevron.left").padding(8).background(Color.primary.opacity(0.05))
            .clipShape(Circle())
        }.buttonStyle(.plain).opacity(onCancel == nil ? 0 : 1)
        Spacer()
        Text(name.isEmpty ? "New Server" : name).font(.headline)
        Spacer()
        Color.clear.frame(width: 30, height: 30)
      }
      VStack(alignment: .leading, spacing: 20) {
        GlassTextField(icon: "tag", title: "Friendly Name", text: $name)
        GlassTextField(icon: "network", title: "IP Address", text: $ipAddress)
        GlassTextField(icon: "person", title: "Username", text: $username)
        VStack(alignment: .leading, spacing: 6) {
          Label("SSH Key", systemImage: "key").font(.caption).foregroundStyle(.secondary)
          Menu {
            Text("Select a key...").tag("")
            ForEach(availableKeys, id: \.self) { key in Button(key) { selectedKeyPath = key } }
            Button("Manual Entry...") { selectedKeyPath = "MANUAL" }
          } label: {
            HStack {
              Text(
                selectedKeyPath.isEmpty
                  ? "Select Key"
                  : (URL(string: selectedKeyPath)?.lastPathComponent ?? selectedKeyPath))
              Spacer()
              Image(systemName: "chevron.up.chevron.down").font(.caption)
            }.padding(10).background(Color.primary.opacity(0.05)).cornerRadius(8)
          }.menuStyle(.borderlessButton)
        }
        if selectedKeyPath == "MANUAL" {
          GlassTextField(icon: "folder", title: "Path", text: $selectedKeyPath)
        }
      }.padding(25).background(.ultraThinMaterial).cornerRadius(16)
      HStack(spacing: 15) {
        Button("Save") {
          _ = save()
          onCancel?()
        }.padding().background(Color.primary.opacity(0.05)).cornerRadius(12)
        Button(action: connect) {
          HStack {
            if isConnecting {
              ProgressView().controlSize(.small)
            } else {
              Text("Connect")
              Image(systemName: "arrow.right")
            }
          }
          .font(.headline).frame(maxWidth: .infinity).padding().background(Color.accentColor)
          .foregroundStyle(.white).cornerRadius(12)
        }.buttonStyle(.plain).disabled(isConnecting)
      }
    }.padding(40).liquidGlass().frame(width: 480).onAppear(perform: loadSSHKeys)
  }
  private func loadSSHKeys() {
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
  private func save() -> SavedSession {
    let existing = sessionService.sessions.first(where: { $0.id == id })
    let session = SavedSession(
      id: id, name: name, ipAddress: ipAddress, username: username, keyPath: selectedKeyPath,
      environment: environment, savedLayouts: existing?.savedLayouts ?? [],
      customPorts: existing?.customPorts ?? [])
    sessionService.save(session: session)
    return session
  }
  private func connect() {
    isConnecting = true
    let session = save()
    Task {
      let result = await SSHService.testConnection(
        ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
      await MainActor.run {
        isConnecting = false
        if case .success = result {
          onConnect(session)
        } else {
          SSHService.openTerminalForDebugging(
            ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
        }
      }
    }
  }
}

// MARK: - Port Mapping View

struct PortMappingView: View {

  @State var session: SavedSession

  let onDisconnect: () -> Void

  @EnvironmentObject var sessionService: SessionService

  @StateObject private var tunnelManager = TunnelManager()

  @StateObject private var syncManager = SyncManager()

  @State private var isHoveringApply = false

  @State private var ports: [RemotePort] = []

  @State private var isLoading = true

  @State private var showSaveLayoutAlert = false

  @State private var newLayoutName = ""

  @State private var selectedConflict: RemotePort?

  @State private var showAddCustomPort = false

  @State private var searchText = ""

  @State private var showSyncConfig = false

  @State private var showPasswordPrompt = false

  @State private var sshPassword = ""

  var filteredPorts: [RemotePort] {

    let list =
      searchText.isEmpty
      ? ports
      : ports.filter { port in

        port.containerName.localizedCaseInsensitiveContains(searchText)
          ||

          String(port.remotePort).contains(searchText)
          ||

          String(port.localPort).contains(searchText)

      }

    return list.sorted { p1, p2 in score(p1.status) < score(p2.status) }

  }

  private func score(_ status: PortStatus) -> Int {

    switch status {

    case .connected: return 0

    case .preActivated: return 1

    case .disconnected: return 2

    case .occupied: return 3

    }

  }

  var body: some View {

    VStack(spacing: 0) {

      HStack(alignment: .center) {  // Alinhamento centralizado rigoroso

        HStack(spacing: 12) {

          StatusIndicator(active: tunnelManager.isConnected)

            .frame(height: 32)

          VStack(alignment: .leading, spacing: 0) {

            Text(tunnelManager.isConnected ? "TUNNEL ACTIVE" : "CONNECTED")

              .font(.system(size: 8, weight: .black))

              .foregroundStyle(.secondary)

            Text(session.name)

              .font(.subheadline)

              .fontWeight(.semibold)

          }

        }

        Spacer()

        HStack(spacing: 16) {

          Button(action: { showSyncConfig = true }) {

            Image(systemName: "arrow.triangle.2.circlepath")

              .font(.system(size: 14, weight: .semibold))

              .foregroundStyle(.secondary)

              .padding(8)

              .background(.ultraThinMaterial)

              .clipShape(Circle())

          }

          .buttonStyle(.plain)

          LayoutMenu(
            session: session, onApply: applyLayout,
            onSaveNew: {

              newLayoutName = ""

              showSaveLayoutAlert = true

            }
          )

          .frame(height: 32)

          GlassPowerButton {

            withAnimation(.easeInOut(duration: 0.3)) {

              tunnelManager.stopTunnel()

              syncManager.stopAll()

              onDisconnect()

            }

          }

        }

      }

      .padding(.horizontal, 20)

      .padding(.vertical, 16)

      .background(.ultraThinMaterial)  // Base de vidro para o cabeçalho

      HStack(spacing: 10) {

        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

        TextField("Search services, ports...", text: $searchText).textFieldStyle(.plain)

        if !searchText.isEmpty {

          Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
          }.buttonStyle(.plain)

        }

      }

      .padding(10).background(Color.primary.opacity(0.05)).cornerRadius(10)

      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))

      .padding(.horizontal, 20).padding(.top, 10)

      if let error = tunnelManager.error {

        HStack {

          Image(systemName: "exclamationmark.triangle.fill")

          Text(error).font(.caption)
          Spacer()
          Button("Dismiss") { tunnelManager.error = nil }

        }.padding(10).background(Color.red.opacity(0.1)).foregroundStyle(.red).cornerRadius(8)
          .padding(.horizontal)

      }

      if isLoading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      else {

        ScrollView {

          VStack(spacing: 12) {

            if filteredPorts.isEmpty {
              Text("No matching services found.").foregroundStyle(.secondary).padding(.top, 20)
            }

            else {

              ForEach(filteredPorts) { port in

                if let index = ports.firstIndex(where: { $0.id == port.id }) {

                  TunnelRow(port: $ports[index], onConflictTap: { selectedConflict = ports[index] })

                    .contextMenu {

                      if ports[index].isCustom {

                        Button("Delete Custom Port", role: .destructive) {
                          deleteCustomPort(ports[index])
                        }

                      }

                    }

                }

              }

            }

          }.padding()

        }

      }

      VStack(spacing: 0) {

        Divider()

        HStack {

          Label("\(filteredPorts.count) Services", systemImage: "cube").font(.caption)
            .foregroundStyle(.secondary)

          Button(action: { showAddCustomPort = true }) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
          }.buttonStyle(.plain)

          Spacer()

          if tunnelManager.isConnected {

            Button(action: { tunnelManager.stopTunnel() }) {

              Text("Stop Tunnels").font(.subheadline.bold()).padding(.horizontal, 24).padding(
                .vertical, 10
              )

              .background(Color.red.opacity(0.1)).foregroundStyle(.red).cornerRadius(10)

              .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))

            }.buttonStyle(.plain)

          } else {

            Button(action: { checkAuthAndApply() }) {

              HStack {
                if tunnelManager.isConnecting { ProgressView().controlSize(.small) }
                Text("Apply Tunnels").font(.subheadline.bold())
              }

              .padding(.horizontal, 24).padding(.vertical, 10)

              .background(

                RoundedRectangle(cornerRadius: 10)

                  .fill(Color.accentColor.opacity(isHoveringApply ? 0.4 : 0.2))

              )

              .glassEffect(in: RoundedRectangle(cornerRadius: 10))

              .overlay(

                RoundedRectangle(cornerRadius: 10)

                  .stroke(Color.accentColor.opacity(isHoveringApply ? 0.8 : 0.4), lineWidth: 1)

              )

              .foregroundStyle(Color.accentColor)

              .scaleEffect(isHoveringApply ? 1.02 : 1.0)

              .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringApply)

            }

            .buttonStyle(.plain)

            .disabled(
              ports.filter { $0.status == .preActivated }.isEmpty || tunnelManager.isConnecting
            )

            .onHover { isHoveringApply = $0 }

          }

        }.padding().background(.ultraThinMaterial)

      }

    }

    .liquidGlass()

    .onAppear(perform: setupView)

    .onChange(of: session) { _, newValue in

      syncManager.update(session: newValue)

    }

    .alert("Save Layout", isPresented: $showSaveLayoutAlert) {

      TextField("Layout Name", text: $newLayoutName)

      Button("Cancel", role: .cancel) {}
      Button("Save") { saveLayout() }

    }
    .sheet(item: $selectedConflict) { port in
      ConflictSheet(port: String(port.localPort), process: port.status.conflictProcess ?? "Unknown")
    }
    .sheet(isPresented: $showAddCustomPort) { AddCustomPortSheet { addCustomPort($0) } }
    .sheet(isPresented: $showSyncConfig) {
      SyncView(session: $session, syncManager: syncManager).frame(width: 600, height: 500)
    }
    .sheet(isPresented: $showPasswordPrompt) {
      VStack(spacing: 20) {
        Text("Authentication Required").font(.headline)
        Text("Enter password for \(session.username)@\(session.ipAddress)").font(.caption)
          .foregroundStyle(.secondary)
        SecureField("Password", text: $sshPassword).textFieldStyle(.plain).padding(10).background(
          Color.primary.opacity(0.05)
        ).cornerRadius(8).frame(width: 250)
        HStack {
          Button("Cancel") { showPasswordPrompt = false }
          Button("Connect") {
            showPasswordPrompt = false
            startTunneling(password: sshPassword)
          }.buttonStyle(.borderedProminent)
        }
      }.padding(30)
    }
  }

  private func setupView() {
    loadData()
    tunnelManager.onTermination = {
      for i in ports.indices {
        if ports[i].status == .connected { ports[i].status = .preActivated }
      }
    }
    syncManager.update(session: session)
  }

  private func loadData() {
    isLoading = true
    Task {
      do {
        let containers = try await DockerService.fetchContainers(
          ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
        var combinedPorts = containers.flatMap { c in
          c.ports.map { p in
            RemotePort(
              containerName: c.name, remotePort: p, localPort: p, status: .disconnected,
              isCustom: false)
          }
        }
        let custom = session.customPorts.map { c in
          RemotePort(
            containerName: c.name, remotePort: c.remotePort, localPort: c.localPort,
            status: .disconnected, isCustom: true, customId: c.id)
        }
        combinedPorts.append(contentsOf: custom)
        for i in 0..<combinedPorts.count {
          let check = PortCheckService.checkPort(combinedPorts[i].localPort)
          if case .occupied(let proc) = check { combinedPorts[i].status = .occupied(process: proc) }
        }
        await MainActor.run {
          self.ports = combinedPorts
          self.isLoading = false
        }
      } catch { await MainActor.run { self.isLoading = false } }
    }
  }

  private func addCustomPort(_ mapping: CustomPortMapping) {
    session.customPorts.append(mapping)
    sessionService.save(session: session)
    loadData()
  }
  private func deleteCustomPort(_ port: RemotePort) {
    guard let id = port.customId else { return }
    session.customPorts.removeAll { $0.id == id }
    sessionService.save(session: session)
    loadData()
  }
  private func saveLayout() {
    let active = ports.filter { $0.status == .preActivated || $0.status == .connected }
    let mappings = Dictionary(uniqueKeysWithValues: active.map { ($0.remotePort, $0.localPort) })
    session.savedLayouts.append(PortLayout(name: newLayoutName, mappings: mappings))
    sessionService.save(session: session)
  }
  private func applyLayout(_ layout: PortLayout) {
    if tunnelManager.isConnected { return }
    for i in ports.indices {
      if ports[i].status == .preActivated { ports[i].status = .disconnected }
    }
    for i in ports.indices {
      if let local = layout.mappings[ports[i].remotePort] {
        ports[i].localPort = local
        let check = PortCheckService.checkPort(local)
        if case .occupied(let proc) = check {
          ports[i].status = .occupied(process: proc)
        } else {
          ports[i].status = .preActivated
        }
      }
    }
  }
  private func checkAuthAndApply() {
    Task {
      let result = await SSHService.testConnection(
        ip: session.ipAddress, user: session.username, keyPath: session.keyPath)
      await MainActor.run {
        if case .success = result {
          startTunneling(password: nil)
        } else {
          showPasswordPrompt = true
        }
      }
    }
  }
  private func startTunneling(password: String?) {
    let active = ports.filter { $0.status == .preActivated }
    guard !active.isEmpty else { return }
    Task {
      await tunnelManager.startTunnel(session: session, ports: active, password: password)
      if tunnelManager.isConnected {
        for i in ports.indices {
          if ports[i].status == .preActivated { ports[i].status = .connected }
        }
      }
    }
  }
}

// MARK: - Refined Components

struct StatusIndicator: View {
  let active: Bool
  var body: some View {
    ZStack {
      Circle().fill(active ? Color.green : Color.orange).frame(width: 8, height: 8)
      Circle().stroke(.white.opacity(0.2), lineWidth: 1).frame(width: 8, height: 8)
      if active {
        Circle().stroke(Color.green.opacity(0.5), lineWidth: 4).frame(width: 14, height: 14).blur(
          radius: 2)
      }
    }.padding(8).background(.ultraThinMaterial).clipShape(Circle())
  }
}

struct LayoutMenu: View {
  let session: SavedSession
  let onApply: (PortLayout) -> Void
  let onSaveNew: () -> Void
  var body: some View {
    Menu {
      ForEach(session.savedLayouts) { layout in Button(layout.name) { onApply(layout) } }
      Button("Save Current Layout...", action: onSaveNew)
    } label: {
      Label("Layouts", systemImage: "square.dashed.inset.filled").font(.caption.bold())
        .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(
          20)
    }.menuStyle(.borderlessButton)
  }
}

struct PortPill: View {
  let remote: String
  let local: String
  let status: PortStatus
  var onConflictTap: () -> Void
  var onToggle: () -> Void

  // 0.0: Desconectado | 0.3: Pre-Activated (Próximas) | 1.0: Conectado (Fundidas)
  private var progress: CGFloat {
    switch status {
    case .connected: return 1.0
    case .preActivated: return 0.3
    default: return 0.0
    }
  }

  private var isOccupied: Bool {
    if case .occupied = status { return true }
    return false
  }

  var body: some View {
    ExpandableMergingGlassContainer(
      size: CGSize(width: 60, height: 30),
      progress: progress
    ) {
      // Pill Remote
      Text(remote)
        .font(.system(.caption, design: .monospaced).bold())
        .foregroundStyle(status == .preActivated ? .green : .primary)

      // Pill Local
      HStack(spacing: 4) {
        Text(local)
        if isOccupied { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)) }
      }
      .font(.system(.caption, design: .monospaced).bold())
      .foregroundStyle(status == .preActivated ? .green : .primary)

    } mergedLabel: {
      // Pílula Fundida (Aparece em progress 1.0)
      HStack(spacing: 8) {
        Image(systemName: "dot.radiowaves.left.and.right")
          .font(.system(size: 10, weight: .black))
        Text("\(remote) : \(local)")
          .font(.system(.caption, design: .monospaced).bold())
      }
      .foregroundStyle(.green)
      .frame(width: 130, height: 32)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .contentShape(Rectangle())
    .onTapGesture {
      if isOccupied { onConflictTap() } else { onToggle() }
    }
  }
}

// Lógica de aproximação baseada no progress
private func calculatePillOffset(proxy: GeometryProxy, p: CGFloat) -> CGFloat {
  let currentX = proxy.frame(in: .named("PILL_LOCAL")).midX
  // 65 é o centro aproximado (130 / 2)
  let targetX: CGFloat = 65
  return (targetX - currentX) * p
}

struct ExpandableMergingGlassContainer<Content: View, MergedLabel: View>: View {
  var size: CGSize
  var progress: CGFloat
  @ViewBuilder var content: Content
  @ViewBuilder var mergedLabel: MergedLabel

  @State private var containerWidth: CGFloat = 0

  var body: some View {
    ZStack(alignment: .center) {
      HStack(spacing: spacing) {
        ForEach(subviews: content) { subview in
          subview
            .blur(radius: 15 * (progress == 1.0 ? 1 : 0))  // Só blura na fusão total
            .opacity(progress == 1.0 ? 0 : 1)
            .frame(width: size.width, height: size.height)
            .glassEffect(.regular, in: .capsule)
            .visualEffect { [progress] content, proxy in
              content.offset(x: calculatePillOffset(proxy: proxy, p: progress))
            }
            .fixedSize()
        }
      }
      // Mantém o espaço ocupado para a pílula não sumir
      .frame(width: max(130, containerWidth))

      // A pílula grande fundida
      mergedLabel
        .glassEffect(.regular, in: .capsule)
        .opacity(progress == 1.0 ? 1 : 0)
        .scaleEffect(progress == 1.0 ? 1.0 : 0.8)
        .blur(radius: progress == 1.0 ? 0 : 10)
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: {
      containerWidth = $0
    }
    .coordinateSpace(.named("PILL_LOCAL"))
    .scaleEffect(x: 1 + (scaleProgress * 0.15), y: 1 - (scaleProgress * 0.15))
    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
  }

  private var scaleProgress: CGFloat {
    progress > 0.5 ? (1 - progress) / 0.5 : (progress / 0.5)
  }

  private var spacing: CGFloat {
    // Diminui o espaço de 40 para 10 no pre-activated, e para 0 na fusão
    if progress >= 1.0 { return 0 }
    return 40 - (100 * progress)  // Faz as pílulas "correrem" uma para a outra
  }
}

struct ConflictSheet: View {
  @Environment(\.dismiss) var dismiss
  let port: String
  let process: String
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "exclamationmark.shield.fill").font(.system(size: 48)).foregroundColor(.red)
      VStack(spacing: 8) {
        Text("Port Conflict Detected").font(.headline)
        Text("Local port \(port) is already in use by another application.").font(.subheadline)
          .foregroundColor(.secondary).multilineTextAlignment(.center)
      }
      HStack {
        Text("Process Name:")
        Spacer()
        Text(process).bold()
      }.padding().background(Color.primary.opacity(0.05)).cornerRadius(10)
      Button("Got it") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
    }.padding(30).frame(width: 320)
  }
}

struct TunnelRow: View {
  @Binding var port: RemotePort
  var onConflictTap: () -> Void

  var body: some View {
    HStack {
      Text(port.containerName)
        .font(.system(.body, design: .rounded))
        .fontWeight(.medium)

      Spacer()

      // A pílula agora gerencia sua própria fusão
      PortPill(
        remote: String(port.remotePort),
        local: String(port.localPort),
        status: port.status,
        onConflictTap: onConflictTap,
        onToggle: toggleActivation
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    // Usamos um material bem fino para a linha toda
    .background(.ultraThinMaterial.opacity(0.3))
    .cornerRadius(18)
  }

  private func toggleActivation() {
    withAnimation(.spring()) {
      if port.status == .disconnected {
        port.status = .preActivated
      } else if port.status == .preActivated {
        port.status = .disconnected
      }
    }
  }
}

// MARK: - Add Custom Port Sheet

struct AddCustomPortSheet: View {
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var remotePort = ""
  @State private var localPort = ""
  let onSave: (CustomPortMapping) -> Void
  var body: some View {
    VStack(spacing: 20) {
      Text("Add Custom Service").font(.headline)
      VStack(alignment: .leading) {
        GlassTextField(icon: "tag", title: "Service Name", text: $name)
        GlassTextField(icon: "server.rack", title: "Remote Port", text: $remotePort)
        GlassTextField(
          icon: "laptopcomputer", title: "Local Port (Default: Same)", text: $localPort)
      }.padding().background(.ultraThinMaterial).cornerRadius(12)
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Add") {
          guard let rPort = Int(remotePort), !name.isEmpty else { return }
          onSave(
            CustomPortMapping(name: name, remotePort: rPort, localPort: Int(localPort) ?? rPort))
          dismiss()
        }.keyboardShortcut(.defaultAction).disabled(name.isEmpty || Int(remotePort) == nil)
      }
    }.padding().frame(width: 300)
  }
}

// MARK: - Data Models

struct RemotePort: Identifiable {
  let id = UUID()
  let containerName: String
  let remotePort: Int
  var localPort: Int
  var status: PortStatus
  var isCustom: Bool
  var customId: UUID? = nil
}

enum PortStatus: Equatable {
  case connected, disconnected, preActivated
  case occupied(process: String)
  var themeColor: Color {
    switch self {
    case .connected: return .green
    case .disconnected: return .gray
    case .preActivated: return Color.green.opacity(0.6)
    case .occupied: return .red
    }
  }
  var conflictProcess: String? {
    if case .occupied(let p) = self { return p }
    return nil
  }
}
