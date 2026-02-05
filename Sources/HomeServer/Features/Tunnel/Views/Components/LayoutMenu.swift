import SwiftUI

struct LayoutMenu: View {
  let session: SavedSession
  let onApply: (PortLayout) -> Void
  let onSaveNew: () -> Void
  var body: some View {
    Menu {
      ForEach(session.savedLayouts) { layout in Button(layout.name) { onApply(layout) } }
      Button("Save Current Layout...", action: onSaveNew)
    } label: {
      Label("Layouts", systemImage: "square.dashed.inset.filled").font(.caption.bold())
        .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(
          20)
    }.menuStyle(.borderlessButton)
  }
}
