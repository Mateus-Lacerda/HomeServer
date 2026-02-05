import SwiftUI

struct LiquidGlassModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial)
      .cornerRadius(18)
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
          )
      )
      .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
  }
}

extension View { func liquidGlass() -> some View { self.modifier(LiquidGlassModifier()) } }
