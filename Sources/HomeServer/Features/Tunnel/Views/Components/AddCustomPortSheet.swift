import SwiftUI

struct AddCustomPortSheet: View {
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var remotePort = ""
  @State private var localPort = ""
  let onSave: (CustomPortMapping) -> Void
  var body: some View {
    VStack(spacing: 20) {
      Text("Add Custom Service").font(.headline)
      VStack(alignment: .leading) {
        GlassTextField(icon: "tag", title: "Service Name", text: $name)
        GlassTextField(icon: "server.rack", title: "Remote Port", text: $remotePort)
        GlassTextField(
          icon: "laptopcomputer", title: "Local Port (Default: Same)", text: $localPort)
      }.padding().background(.ultraThinMaterial).cornerRadius(12)
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Add") {
          guard let rPort = Int(remotePort), !name.isEmpty else { return }
          onSave(
            CustomPortMapping(name: name, remotePort: rPort, localPort: Int(localPort) ?? rPort))
          dismiss()
        }.keyboardShortcut(.defaultAction).disabled(name.isEmpty || Int(remotePort) == nil)
      }
    }.padding().frame(width: 300)
  }
}
