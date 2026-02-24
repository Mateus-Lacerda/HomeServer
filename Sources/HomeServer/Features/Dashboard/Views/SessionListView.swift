import SwiftUI

struct SessionListView: View {
  @EnvironmentObject var sessionService: SessionService
  let onSelect: (SavedSession) -> Void
  let onEdit: (SavedSession) -> Void
  let onNew: () -> Void
  @State private var isHoveringPlus = false

  let cardWidth: CGFloat = 250

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        if let logoURL = Bundle.module.url(forResource: "logo", withExtension: "svg"),
           let logoImage = NSImage(contentsOf: logoURL) {
          Image(nsImage: logoImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
        }
        VStack(alignment: .leading) {
          Text("My Labs").font(.system(size: 32, weight: .light))
          Text("Select a server to connect").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button(action: onNew) {
          Image(systemName: "plus").font(.headline).padding(10)
            .background(
              Circle()
                .fill(Color.accentColor.opacity(isHoveringPlus ? 0.4 : 0.2))
            )
            .glassEffect(in: .circle)
            .overlay(
              Circle().stroke(Color.accentColor.opacity(isHoveringPlus ? 0.6 : 0.3), lineWidth: 1)
            )
            .scaleEffect(isHoveringPlus ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringPlus = $0 }
      }
      .padding(.horizontal, 20)

      ScrollView {
        LazyVGrid(
          columns: [
            GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: 20)
          ],
          alignment: .leading,
          spacing: 20
        ) {
          ForEach(sessionService.sessions) { session in
            SessionCard(
              session: session,
              onSelect: { onSelect(session) },
              onEdit: { onEdit(session) },
              onDelete: { sessionService.delete(id: session.id) }
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        Spacer(minLength: 0)
      }
    }
    .padding(.top, 30)
    .liquidGlass()
  }
}
