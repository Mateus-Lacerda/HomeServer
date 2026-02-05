import Foundation
import SwiftUI

struct RemotePort: Identifiable {
  let id = UUID()
  let containerName: String
  let remotePort: Int
  var localPort: Int
  var status: PortStatus
  var isCustom: Bool
  var customId: UUID? = nil
}

enum PortStatus: Equatable {
  case connected, disconnected, preActivated
  case occupied(process: String)
  var themeColor: Color {
    switch self {
    case .connected: return .green
    case .disconnected: return .gray
    case .preActivated: return .yellow
    case .occupied: return .red
    }
  }

  var conflictProcess: String? {
    if case .occupied(let process) = self {
      return process
    }
    return nil
  }
}
