import SwiftUI

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
              sessionService: sessionService,
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
            sessionService: sessionService,
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
