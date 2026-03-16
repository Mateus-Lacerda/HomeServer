import SwiftUI

struct PortMappingView: View {

  @State var session: SavedSession

  let onDisconnect: () -> Void

  @EnvironmentObject var sessionService: SessionService

  @StateObject private var tunnelViewModel = TunnelViewModel()

  @State private var isHoveringApply = false

  @State private var ports: [RemotePort] = []

  @State private var isLoading = true

  @State private var showSaveLayoutAlert = false

  @State private var newLayoutName = ""

  @State private var selectedConflict: RemotePort?

  @State private var showAddCustomPort = false

  @State private var searchText = ""

  @State private var showPasswordPrompt = false

  @State private var sshPassword = ""

  @State private var renamingLayout: PortLayout?

  @State private var renameText = ""

  @State private var showRenameAlert = false

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

          StatusIndicator(active: tunnelViewModel.isConnected)

            .frame(height: 32)

          VStack(alignment: .leading, spacing: 0) {

            Text(tunnelViewModel.isConnected ? "TUNNEL ACTIVE" : "CONNECTED")

              .font(.system(size: 8, weight: .black))

              .foregroundStyle(.secondary)

            Text(session.name)

              .font(.subheadline)

              .fontWeight(.semibold)

          }

        }

        Spacer()

        HStack(spacing: 16) {

          LayoutMenu(
            session: session, onApply: applyLayout,
            onSaveNew: {
              newLayoutName = ""
              showSaveLayoutAlert = true
            },
            onSaveToCurrent: { layout in
              overwriteLayout(layout)
            },
            onRename: { layout in
              renamingLayout = layout
              renameText = layout.name
              showRenameAlert = true
            },
            onDelete: { layout in
              deleteLayout(layout)
            }
          )

          .frame(height: 32)

          GlassPowerButton {

            withAnimation(.easeInOut(duration: 0.3)) {

              tunnelViewModel.stopTunnel()

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

      if let error = tunnelViewModel.error {

        HStack {

          Image(systemName: "exclamationmark.triangle.fill")

          Text(error).font(.caption)
          Spacer()
          Button("Dismiss") { tunnelViewModel.error = nil }

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

          if tunnelViewModel.isConnected {

            Button(action: { tunnelViewModel.stopTunnel() }) {

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
                if tunnelViewModel.isConnecting { ProgressView().controlSize(.small) }
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
              ports.filter { $0.status == .preActivated }.isEmpty || tunnelViewModel.isConnecting
            )

            .onHover { isHoveringApply = $0 }

          }

        }.padding().background(.ultraThinMaterial)

      }

    }

    .liquidGlass()

    .onAppear(perform: setupView)

    .alert("Save Layout", isPresented: $showSaveLayoutAlert) {

      TextField("Layout Name", text: $newLayoutName)

      Button("Cancel", role: .cancel) {}
      Button("Save") { saveLayout() }

    }
    .alert("Rename Layout", isPresented: $showRenameAlert) {
      TextField("New Name", text: $renameText)
      Button("Cancel", role: .cancel) {}
      Button("Rename") { renameLayout() }
    }
    .sheet(item: $selectedConflict) { port in
      ConflictSheet(port: String(port.localPort), process: port.status.conflictProcess ?? "Unknown")
    }
    .sheet(isPresented: $showAddCustomPort) { AddCustomPortSheet { addCustomPort($0) } }
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
    tunnelViewModel.onTermination = {
      for i in ports.indices {
        if ports[i].status == .connected { ports[i].status = .preActivated }
      }
    }
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
        let persistedState = TunnelState.load()
        let persistedLocalPorts = Set(persistedState?.ports.map { $0[0] } ?? [])
        let isOurSession = persistedState?.sessionId == session.id

        for i in 0..<combinedPorts.count {
          let check = PortCheckService.checkPort(combinedPorts[i].localPort)
          if case .occupied(let proc) = check {
            if isOurSession && persistedLocalPorts.contains(combinedPorts[i].localPort) {
              combinedPorts[i].status = .connected
            } else {
              combinedPorts[i].status = .occupied(process: proc)
            }
          }
        }
        await MainActor.run {
          self.ports = combinedPorts
          self.isLoading = false
          if isOurSession, let state = persistedState {
            let connectedPorts = combinedPorts.filter { $0.status == .connected }
            tunnelViewModel.reclaim(state: state, session: session, ports: connectedPorts)
          }
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
  private func overwriteLayout(_ layout: PortLayout) {
    guard let idx = session.savedLayouts.firstIndex(where: { $0.id == layout.id }) else { return }
    let active = ports.filter { $0.status == .preActivated || $0.status == .connected }
    let mappings = Dictionary(uniqueKeysWithValues: active.map { ($0.remotePort, $0.localPort) })
    session.savedLayouts[idx].mappings = mappings
    sessionService.save(session: session)
  }
  private func deleteLayout(_ layout: PortLayout) {
    session.savedLayouts.removeAll { $0.id == layout.id }
    sessionService.save(session: session)
  }
  private func renameLayout() {
    guard let layout = renamingLayout,
          let idx = session.savedLayouts.firstIndex(where: { $0.id == layout.id }) else { return }
    session.savedLayouts[idx].name = renameText
    sessionService.save(session: session)
    renamingLayout = nil
  }
  private func applyLayout(_ layout: PortLayout) {
    if tunnelViewModel.isConnected { return }
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
      await tunnelViewModel.startTunnel(session: session, ports: active, password: password)
      if tunnelViewModel.isConnected {
        for i in ports.indices {
          if ports[i].status == .preActivated { ports[i].status = .connected }
        }
      }
    }
  }
}
