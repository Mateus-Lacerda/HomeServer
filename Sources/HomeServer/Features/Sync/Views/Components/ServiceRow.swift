import SwiftUI

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
