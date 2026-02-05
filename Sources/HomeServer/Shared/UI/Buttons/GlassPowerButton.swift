import SwiftUI

struct GlassPowerButton: View {
  var action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .fill(.red.opacity(isHovering ? 0.5 : 0.3))
          .glassEffect()

        Image(systemName: "power")
          .font(.system(size: 14, weight: .black))
          .foregroundColor(.white)
          .shadow(color: .black.opacity(0.2), radius: 1)
      }
      .frame(width: 32, height: 32)
      .scaleEffect(isHovering ? 1.1 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }
}
