import Foundation
import SwiftUI

// Define route types for navigation
enum Route: Hashable {
  case performer(StashScene.Performer)
  case marker(SceneMarker)
  case scene(StashScene)
  case tag(StashScene.Tag)
  case tagMarkers(StashScene.Tag)
}

class NavigationModel: ObservableObject {
  // Start on a neutral screen by default to avoid showing media immediately
  @Published var selectedTab: NavigationItem = .settings
  @Published var navigationPath = NavigationPath()

  func navigateTo(_ tab: NavigationItem) {
    selectedTab = tab
    // Clear navigation path when switching tabs
    navigationPath = NavigationPath()
  }

  func navigate(to route: Route) {
    navigationPath.append(route)
  }

  func popToRoot() {
    navigationPath = NavigationPath()
  }
}
