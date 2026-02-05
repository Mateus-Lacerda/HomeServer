import Foundation
import SwiftUI

enum AppState: Equatable {
  case list
  case editor(session: SavedSession?)
  case connected(session: SavedSession)
}
