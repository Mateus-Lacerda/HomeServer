import SwiftUI

@main
struct HomeServerApp: App {
  @StateObject private var sessionService = SessionService()

  init() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)

    if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
       let icon = NSImage(contentsOf: iconURL) {
      NSApplication.shared.applicationIconImage = icon
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(sessionService)
    }
    .windowStyle(.hiddenTitleBar)
  }
}
