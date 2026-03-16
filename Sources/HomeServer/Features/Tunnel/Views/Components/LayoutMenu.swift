import SwiftUI

struct LayoutMenu: View {
  let session: SavedSession
  let onApply: (PortLayout) -> Void
  let onSaveNew: () -> Void
  var onSaveToCurrent: ((PortLayout) -> Void)?
  var onRename: ((PortLayout) -> Void)?
  var onDelete: ((PortLayout) -> Void)?

  var body: some View {
    Menu {
      ForEach(session.savedLayouts) { layout in
        Menu(layout.name) {
          Button("Apply") { onApply(layout) }
          Button("Save Current Here") { onSaveToCurrent?(layout) }
          Button("Rename...") { onRename?(layout) }
          Divider()
          Button("Delete", role: .destructive) { onDelete?(layout) }
        }
      }
      Divider()
      Button("Save as New...", action: onSaveNew)
    } label: {
      Label("Configurations", systemImage: "square.dashed.inset.filled").font(.caption.bold())
        .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(
          20)
    }.menuStyle(.borderlessButton)
  }
}
