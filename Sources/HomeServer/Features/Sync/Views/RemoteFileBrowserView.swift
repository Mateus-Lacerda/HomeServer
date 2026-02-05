import SwiftUI

struct RemoteFileBrowserView: View {
  let session: SavedSession
  @Binding var currentPath: String
  let onSelect: (String) -> Void
  let onCancel: () -> Void

  @State private var files: [String] = []
  @State private var isLoading = false
  @State private var error: String?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Remote Browser").font(.headline)
        Spacer()
        Button(action: onCancel) {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()
      .background(.ultraThinMaterial)

      HStack {
        Text(currentPath.isEmpty ? "/" : currentPath)
          .font(.caption.monospaced())
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(8)
          .background(Color.primary.opacity(0.05))
          .cornerRadius(6)

        if currentPath != "/" && !currentPath.isEmpty {
          Button(action: goUp) { Image(systemName: "arrow.up.folder") }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 8)

      if isLoading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = error {
        Text(error).foregroundColor(.red).padding()
        Button("Retry") { loadFiles() }
      } else {
        List {
          ForEach(files, id: \.self) { file in
            HStack {
              Image(systemName: file.hasSuffix("/") ? "folder.fill" : "doc")
                .foregroundStyle(file.hasSuffix("/") ? .blue : .secondary)
              Text(file)
              Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
              if file.hasSuffix("/") {
                navigate(to: file)
              } else {
                onSelect(fullPath(for: file))
              }
            }
          }
        }
        .listStyle(.plain)
      }

      HStack {
        Button("Select Current Folder") { onSelect(currentPath) }
          .disabled(currentPath.isEmpty)
        Spacer()
      }
      .padding()
      .background(.ultraThinMaterial)
    }
    .onAppear(perform: loadFiles)
  }

  private func fullPath(for file: String) -> String {
    let cleanPath = currentPath.hasSuffix("/") ? currentPath : currentPath + "/"
    return cleanPath + file
  }

  private func navigate(to dir: String) {
    let cleanPath = currentPath.hasSuffix("/") ? currentPath : currentPath + "/"
    currentPath = cleanPath + dir
    loadFiles()
  }

  private func goUp() {
    let components = currentPath.split(separator: "/").dropLast()
    currentPath = "/" + components.joined(separator: "/")
    if !currentPath.hasSuffix("/") { currentPath += "/" }
    loadFiles()
  }

  private func loadFiles() {
    isLoading = true
    error = nil
    Task {
      do {
        let list = try await SSHService.listDirectory(
          ip: session.ipAddress,
          user: session.username,
          keyPath: session.keyPath,
          path: currentPath.isEmpty ? "/" : currentPath
        )
        await MainActor.run {
          self.files = list.sorted {
            if $0.hasSuffix("/") && !$1.hasSuffix("/") { return true }
            if !$0.hasSuffix("/") && $1.hasSuffix("/") { return false }
            return $0 < $1
          }
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.error = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
}
