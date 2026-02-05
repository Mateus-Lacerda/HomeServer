import SwiftUI

struct StatusIndicator: View {
  let active: Bool
  var body: some View {
    ZStack {
      Circle().fill(active ? Color.green : Color.orange).frame(width: 8, height: 8)
      Circle().stroke(.white.opacity(0.2), lineWidth: 1).frame(width: 8, height: 8)
      if active {
        Circle().stroke(Color.green.opacity(0.5), lineWidth: 4).frame(width: 14, height: 14).blur(
          radius: 2)
      }
    }.padding(8).background(.ultraThinMaterial).clipShape(Circle())
  }
}
