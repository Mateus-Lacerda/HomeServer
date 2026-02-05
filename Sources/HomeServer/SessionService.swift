import Foundation

class SessionService: ObservableObject {
  @Published var sessions: [SavedSession] = []

  private let fileURL: URL

  init() {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent(".homeserver")

    do {
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      print("CRITICAL ERROR: Could not create config directory at \(dir.path): \(error)")
    }

    self.fileURL = dir.appendingPathComponent("sessions.json")
    print("Storage Path: \(self.fileURL.path)")

    load()
  }

  func load() {
    do {
      let data = try Data(contentsOf: fileURL)
      sessions = try JSONDecoder().decode([SavedSession].self, from: data)
      print("Loaded \(sessions.count) sessions from disk.")
    } catch {
      print("No existing sessions loaded (or decode failed): \(error)")
      sessions = []
    }
  }

  func save(session: SavedSession) {
    if let index = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[index] = session
    } else {
      sessions.append(session)
    }
    persist()
  }

  func delete(id: UUID) {
    sessions.removeAll { $0.id == id }
    persist()
  }

  private func persist() {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(sessions)
      try data.write(to: fileURL)
      print("Successfully saved sessions to \(fileURL.path)")
    } catch {
      print("Failed to save sessions: \(error)")
    }
  }
}
