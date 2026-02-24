import SwiftUI

struct LayoutMenu: View {
  let session: SavedSession
  let onApply: (PortLayout) -> Void
  let onSaveNew: () -> Void
  var onRename: ((PortLayout) -> Void)?
  var onDelete: ((PortLayout) -> Void)?

  var body: some View {
    Menu {
      ForEach(session.savedLayouts) { layout in
        Menu(layout.name) {
          Button("Apply") { onApply(layout) }
          Button("Rename...") { onRename?(layout) }
          Divider()
          Button("Delete", role: .destructive) { onDelete?(layout) }
        }
      }
      Divider()
      Button("Save Current Layout...", action: onSaveNew)
    } label: {
      Label("Layouts", systemImage: "square.dashed.inset.filled").font(.caption.bold())
        .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(
          20)
    }.menuStyle(.borderlessButton)
  }
}
