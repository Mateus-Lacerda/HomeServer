import SwiftUI

struct GlassTextField: View {
  let icon: String
  let title: String
  @Binding var text: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary).padding(
        .leading, 4)
      TextField("", text: $text).textFieldStyle(.plain).padding(10).background(
        Color.primary.opacity(0.05)
      ).cornerRadius(8)
    }
  }
}
