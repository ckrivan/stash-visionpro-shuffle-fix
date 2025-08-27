import SwiftUI

enum WindowType: String {
  case performer = "performer"
}

class WindowManager: ObservableObject {
  static let shared = WindowManager()

  @Published var selectedPerformer: StashScene.Performer?

  private init() {}

  func openPerformerWindow(_ performer: StashScene.Performer) {
    selectedPerformer = performer
  }
}
