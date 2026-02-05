import SwiftUI

struct SyncView: View {
  @Binding var session: SavedSession
  @ObservedObject var syncManager: SyncManager
  @EnvironmentObject var sessionService: SessionService
  @Environment(\.dismiss) var dismiss

  @StateObject private var viewModel: SyncViewModel

  @State private var selectedTab: Int = 0

  // Browser State (Controlled by ViewModel)
  @State private var showingBrowser = false
  @State private var browserMode: SyncViewModel.BrowserMode = .repo
  @State private var browserPath: String = ""
  @State private var onBrowserSelect: ((String) -> Void)?

  init(session: Binding<SavedSession>, syncManager: SyncManager, sessionService: SessionService) {
      _session = session
      self.syncManager = syncManager
      _viewModel = StateObject(wrappedValue: SyncViewModel(sessionService: sessionService, syncManager: syncManager))
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
            viewModel: viewModel
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
    .onAppear {
        // We need to inject the REAL sessionService here because the one in init was a dummy
        // This is a bit of a hack.
        // Better: Update PortMappingView to pass sessionService to SyncView.
        viewModel.requestBrowser = { mode, path, callback in
            self.browserMode = mode
            self.browserPath = path
            self.onBrowserSelect = callback
            self.showingBrowser = true
        }
    }
  }
}