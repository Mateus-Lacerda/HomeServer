import SwiftUI

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
