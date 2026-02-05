import SwiftUI

struct SettingsView: View {
  @Binding var session: SavedSession
  @ObservedObject var viewModel: SyncViewModel
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // 1. General Config
        VStack(alignment: .leading, spacing: 10) {
          Text("General").font(.subheadline).foregroundStyle(.secondary)
          GlassTextField(icon: "network", title: "Local IP Address", text: $viewModel.localIP)
            .onChange(of: viewModel.localIP) { _, _ in viewModel.save(session: &session) }

          Button(action: { viewModel.setupRemoteAuth(session: session) }) {
            HStack {
              if viewModel.isAuthorizing { ProgressView().controlSize(.small) }
              Text("Setup Remote Auth Key")
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
          }
          .disabled(viewModel.isAuthorizing)

          if let status = viewModel.authStatus {
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
              viewModel.editingService = nil
              viewModel.resetEditor()
              viewModel.showingEditor = true
            }) {
              Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.plain)
          }

          if let config = session.syncConfig, !config.services.isEmpty {
            ForEach(config.services) { service in
              ServiceRow(service: service) {
                viewModel.editingService = service
                viewModel.loadEditor(service)
                viewModel.showingEditor = true
              }
              .contextMenu {
                Button("Delete", role: .destructive) {
                  viewModel.deleteService(session: &session, id: service.id)
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
      viewModel.initialize(session: session)
    }
    .sheet(isPresented: $viewModel.showingEditor) {
      VStack(spacing: 20) {
        Text(viewModel.editingService == nil ? "Add Service" : "Edit Service").font(.headline)

        ScrollView {
          VStack(alignment: .leading, spacing: 15) {
            Group {
              Text("Remote (Server) Worktree Config").font(.caption.bold()).foregroundStyle(
                .secondary)
              HStack {
                GlassTextField(
                  icon: "archivebox", title: "Main Repo Path (Remote)", text: $viewModel.ed_mainRepoPath)
                Button(action: {
                    viewModel.openBrowserForRepo(session: session, path: viewModel.ed_mainRepoPath) { path in
                        viewModel.ed_mainRepoPath = path
                    }
                }) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              HStack {
                GlassTextField(
                  icon: "folder", title: "Worktree Path (Remote)", text: $viewModel.ed_remoteWorktreePath)
                Button(action: {
                    let startPath = viewModel.ed_mainRepoPath.isEmpty 
                        ? "/home/\(session.username)" 
                        : (URL(fileURLWithPath: viewModel.ed_mainRepoPath).deletingLastPathComponent().path)
                    viewModel.openBrowserForRepo(session: session, path: startPath) { path in
                        viewModel.ed_remoteWorktreePath = path
                    }
                }) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              GlassTextField(
                icon: "network.badge.shield.half.filled", title: "Worktree Remote Name (local-dev)",
                text: $viewModel.ed_worktreeRemoteName)
              GlassTextField(icon: "arrow.branch", title: "Branch", text: $viewModel.ed_branch)
              GlassTextField(icon: "timer", title: "Sync Interval (sec)", text: $viewModel.ed_interval)
              GlassTextField(icon: "terminal", title: "Hot Reload Command", text: $viewModel.ed_cmd)
              Toggle("Trigger on changes", isOn: $viewModel.ed_trigger)

              Button(action: { viewModel.setupRemoteWorktree() }) {
                HStack {
                  if viewModel.isSettingUpWorktree { ProgressView().controlSize(.small) }
                  Text("Setup Worktree on Remote")
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
              }
              .disabled(
                viewModel.isSettingUpWorktree || viewModel.ed_mainRepoPath.isEmpty || viewModel.ed_remoteWorktreePath.isEmpty
                  || viewModel.ed_branch.isEmpty || viewModel.ed_worktreeRemoteName.isEmpty || viewModel.ed_macUser.isEmpty
                  || viewModel.ed_macPath.isEmpty)
            }

            Divider().padding(.vertical, 5)

            Group {
              Text("Local (Mac) Source Config").font(.caption.bold()).foregroundStyle(.secondary)

              VStack(alignment: .leading, spacing: 6) {
                Label("Mac User", systemImage: "person").font(.caption).foregroundStyle(.secondary)
                Menu {
                  ForEach(viewModel.availableUsers, id: \.self) { user in
                    Button(user) { viewModel.ed_macUser = user }
                  }
                } label: {
                  HStack {
                    Text(viewModel.ed_macUser.isEmpty ? "Select User" : viewModel.ed_macUser)
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
                GlassTextField(icon: "laptopcomputer", title: "Local Repo Path", text: $viewModel.ed_macPath)
                Button(action: { viewModel.chooseLocalFolder() }) {
                  Image(systemName: "folder").padding(8).background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }.buttonStyle(.plain)
              }

              GlassTextField(icon: "network", title: "Mac IP Override (Optional)", text: $viewModel.ed_macIP)
            }
          }
          .padding()
        }

        HStack {
          Button("Cancel") { viewModel.showingEditor = false }
          Button("Save") {
            viewModel.saveService(session: &session)
            viewModel.showingEditor = false
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding()
      .frame(width: 450, height: 750)
    }
    .sheet(isPresented: $viewModel.showingSetupLog) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Worktree Setup Log").font(.headline)
        if viewModel.setupLog.isEmpty && viewModel.isSettingUpWorktree {
          ProgressView("Setting up worktree...")
        } else if viewModel.setupLog.isEmpty {
          Text("No log available.")
        } else {
          ScrollView {
            ForEach(viewModel.setupLog) { entry in
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
        Button("Done") { viewModel.showingSetupLog = false }.buttonStyle(.borderedProminent)
      }
      .padding()
      .frame(width: 600, height: 400)
    }
  }
}
