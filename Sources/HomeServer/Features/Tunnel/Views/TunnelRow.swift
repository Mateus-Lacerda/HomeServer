import SwiftUI

struct TunnelRow: View {
  @Binding var port: RemotePort
  var onConflictTap: () -> Void

  var body: some View {
    HStack {
      Text(port.containerName)
        .font(.system(.body, design: .rounded))
        .fontWeight(.medium)

      Spacer()

      // A pílula agora gerencia sua própria fusão
      PortPill(
        remote: String(port.remotePort),
        local: String(port.localPort),
        status: port.status,
        onConflictTap: onConflictTap,
        onToggle: toggleActivation
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    // Usamos um material bem fino para a linha toda
    .background(.ultraThinMaterial.opacity(0.3))
    .cornerRadius(18)
  }

  private func toggleActivation() {
    withAnimation(.spring()) {
      if port.status == .disconnected {
        port.status = .preActivated
      } else if port.status == .preActivated {
        port.status = .disconnected
      }
    }
  }
}
