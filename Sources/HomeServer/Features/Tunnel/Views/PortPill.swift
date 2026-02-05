import SwiftUI

struct PortPill: View {
  let remote: String
  let local: String
  let status: PortStatus
  var onConflictTap: () -> Void
  var onToggle: () -> Void

  // 0.0: Desconectado | 0.3: Pre-Activated (Próximas) | 1.0: Conectado (Fundidas)
  private var progress: CGFloat {
    switch status {
    case .connected: return 1.0
    case .preActivated: return 0.3
    default: return 0.0
    }
  }

  private var isOccupied: Bool {
    if case .occupied = status { return true }
    return false
  }

  var body: some View {
    ExpandableMergingGlassContainer(
      size: CGSize(width: 60, height: 30),
      progress: progress
    ) {
      // Pill Remote
      Text(remote)
        .font(.system(.caption, design: .monospaced).bold())
        .foregroundStyle(status == .preActivated ? .green : .primary)

      // Pill Local
      HStack(spacing: 4) {
        Text(local)
        if isOccupied { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)) }
      }
      .font(.system(.caption, design: .monospaced).bold())
      .foregroundStyle(status == .preActivated ? .green : .primary)

    } mergedLabel: {
      // Pílula Fundida (Aparece em progress 1.0)
      HStack(spacing: 8) {
        Image(systemName: "dot.radiowaves.left.and.right")
          .font(.system(size: 10, weight: .black))
        Text("\(remote) : \(local)")
          .font(.system(.caption, design: .monospaced).bold())
      }
      .foregroundStyle(.green)
      .frame(width: 130, height: 32)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .contentShape(Rectangle())
    .onTapGesture {
      if isOccupied { onConflictTap() } else { onToggle() }
    }
  }
}
