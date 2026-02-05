import SwiftUI

struct SessionCard: View {
  let session: SavedSession
  let onSelect: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void
  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(alignment: .leading, spacing: 15) {
        HStack {
          Image(systemName: "server.rack")
            .font(.title2)
            .foregroundStyle(.secondary)
          Spacer()
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(session.name).font(.headline).lineLimit(1)
          Text(session.ipAddress).font(.caption).foregroundStyle(.secondary)
        }

        Button(action: onSelect) {
          HStack {
            Text("Connect")
            Spacer()
            Image(systemName: "arrow.right")
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(Color.accentColor.opacity(0.1))
          .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 8))
      }
      .padding(16)
      .background(.ultraThinMaterial)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.primary.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
      )

      Menu {
        Button("Edit", action: onEdit)
        Button("Delete", role: .destructive, action: onDelete)
      } label: {
        Image(systemName: "ellipsis")
          .rotationEffect(.degrees(90))
          .padding(10)
          .background(Color.primary.opacity(0.05))
          .clipShape(Circle())
      }
      .menuStyle(.borderlessButton)
      .padding(5)
    }
    .frame(width: 250, height: 150)
    .onHover { hover in
      withAnimation(.easeInOut(duration: 0.2)) { isHovering = hover }
    }
  }
}
