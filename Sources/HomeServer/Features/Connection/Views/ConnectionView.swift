import SwiftUI

struct ConnectionView: View {
  @StateObject private var viewModel: ConnectionViewModel

  init(
    savedSession: SavedSession?, 
    sessionService: SessionService,
    onConnect: @escaping (SavedSession) -> Void,
    onCancel: (() -> Void)?
  ) {
    _viewModel = StateObject(wrappedValue: ConnectionViewModel(
        session: savedSession, 
        sessionService: sessionService, 
        onConnect: onConnect, 
        onCancel: onCancel
    ))
  }

  var body: some View {
    VStack(spacing: 25) {
      HStack {
        Button(action: { viewModel.onCancel?() }) {
          Image(systemName: "chevron.left").padding(8).background(Color.primary.opacity(0.05))
            .clipShape(Circle())
        }.buttonStyle(.plain).opacity(viewModel.onCancel == nil ? 0 : 1)
        Spacer()
        Text(viewModel.name.isEmpty ? "New Server" : viewModel.name).font(.headline)
        Spacer()
        Color.clear.frame(width: 30, height: 30)
      }
      VStack(alignment: .leading, spacing: 20) {
        GlassTextField(icon: "tag", title: "Friendly Name", text: $viewModel.name)
        GlassTextField(icon: "network", title: "IP Address", text: $viewModel.ipAddress)
        GlassTextField(icon: "person", title: "Username", text: $viewModel.username)
        VStack(alignment: .leading, spacing: 6) {
          Label("SSH Key", systemImage: "key").font(.caption).foregroundStyle(.secondary)
          Menu {
            Text("Select a key...").tag("")
            ForEach(viewModel.availableKeys, id: \.self) { key in Button(key) { viewModel.selectedKeyPath = key } }
            Button("Manual Entry...") { viewModel.selectedKeyPath = "MANUAL" }
          } label: {
            HStack {
              Text(
                viewModel.selectedKeyPath.isEmpty
                  ? "Select Key"
                  : (URL(string: viewModel.selectedKeyPath)?.lastPathComponent ?? viewModel.selectedKeyPath))
              Spacer()
              Image(systemName: "chevron.up.chevron.down").font(.caption)
            }.padding(10).background(Color.primary.opacity(0.05)).cornerRadius(8)
          }.menuStyle(.borderlessButton)
        }
        if viewModel.selectedKeyPath == "MANUAL" {
          GlassTextField(icon: "folder", title: "Path", text: $viewModel.selectedKeyPath)
        }
      }.padding(25).background(.ultraThinMaterial).cornerRadius(16)
      HStack(spacing: 15) {
        Button("Save") {
          _ = viewModel.save()
          viewModel.onCancel?()
        }.padding().background(Color.primary.opacity(0.05)).cornerRadius(12)
        Button(action: { viewModel.connect() }) {
          HStack {
            if viewModel.isConnecting {
              ProgressView().controlSize(.small)
            } else {
              Text("Connect")
              Image(systemName: "arrow.right")
            }
          }
          .font(.headline).frame(maxWidth: .infinity).padding().background(Color.accentColor)
          .foregroundStyle(.white).cornerRadius(12)
        }.buttonStyle(.plain).disabled(viewModel.isConnecting)
      }
    }.padding(40).liquidGlass().frame(width: 480).onAppear {
        viewModel.loadSSHKeys()
    }
  }
}
