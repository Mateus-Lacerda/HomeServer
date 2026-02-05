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
