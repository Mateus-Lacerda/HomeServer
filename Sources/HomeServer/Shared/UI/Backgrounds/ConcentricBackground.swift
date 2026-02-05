import SwiftUI

struct ConcentricBackground: View {
  @State private var rotate = false
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black.opacity(0.8), Color.blue.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ).ignoresSafeArea()

      ForEach(0..<5) { i in
        Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
          .frame(width: 300 + CGFloat(i * 150), height: 300 + CGFloat(i * 150))
          .rotationEffect(.degrees(rotate ? 360 : 0))
          .animation(.linear(duration: 80).repeatForever(autoreverses: false), value: rotate)
      }
    }.onAppear { rotate = true }
  }
}
