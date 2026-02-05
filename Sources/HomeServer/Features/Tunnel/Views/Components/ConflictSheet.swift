import SwiftUI

struct ConflictSheet: View {
  @Environment(\.dismiss) var dismiss
  let port: String
  let process: String
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "exclamationmark.shield.fill").font(.system(size: 48)).foregroundColor(.red)
      VStack(spacing: 8) {
        Text("Port Conflict Detected").font(.headline)
        Text("Local port \(port) is already in use by another application.").font(.subheadline)
          .foregroundColor(.secondary).multilineTextAlignment(.center)
      }
      HStack {
        Text("Process Name:")
        Spacer()
        Text(process).bold()
      }.padding().background(Color.primary.opacity(0.05)).cornerRadius(10)
      Button("Got it") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
    }.padding(30).frame(width: 320)
  }
}
