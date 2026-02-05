import SwiftUI

struct SyncStatusRow: View {
  let service: SyncService
  let status: ServiceStatus
  let onSync: () -> Void

  @State private var showDetails = false

  var statusIcon: String {
    switch status.state {
    case .idle: return "clock"
    case .syncing: return "arrow.triangle.2.circlepath"
    case .success: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.triangle.fill"
    }
  }

  var statusColor: Color {
    switch status.state {
    case .idle: return .secondary
    case .syncing: return .blue
    case .success: return .green
    case .failed: return .red
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(URL(fileURLWithPath: service.mainRepoPath).lastPathComponent)  // Updated to mainRepoPath
          .font(.headline)
        Text(service.mainRepoPath)  // Updated to mainRepoPath
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        HStack {
          if status.state == .syncing {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: statusIcon)
              .foregroundStyle(statusColor)
          }

          Text(
            status.state == .syncing
              ? "Syncing..."
              : (status.state == .idle
                ? "Idle" : (status.state == .failed("") ? "Failed" : "Synced"))
          )
          .font(.subheadline)
          .foregroundStyle(statusColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
          if let msg = status.lastMessage, !msg.isEmpty {
            showDetails = true
          }
        }
        .popover(isPresented: $showDetails) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Sync Details").font(.headline)
            if status.log.isEmpty {
              Text("No detailed log available.")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              ScrollView {
                ForEach(status.log) { entry in
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
          }
          .padding()
          .frame(width: 400, height: 300)
        }

        if let lastSync = status.lastSync {
          Text(lastSync, style: .time)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Button(action: onSync) {
        Image(systemName: "arrow.clockwise")
          .padding(8)
          .background(Color.primary.opacity(0.05))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(status.state == .syncing)
      .padding(.leading, 8)
    }
    .padding()
    .background(Color.primary.opacity(0.02))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(statusColor.opacity(0.3), lineWidth: 1)
    )
  }
}
