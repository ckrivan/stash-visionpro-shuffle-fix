import SwiftUI

struct SidebarView: View {
  @Binding var selection: String?

  var body: some View {
    List(selection: $selection) {
      NavigationLink(value: "media") {
        Label("Scenes", systemImage: "film")
      }

      NavigationLink(value: "performers") {
        Label("Performers", systemImage: "person.2")
      }

      NavigationLink(value: "markers") {
        Label("Markers", systemImage: "bookmark.fill")
      }

      NavigationLink(value: "settings") {
        Label("Settings", systemImage: "gear")
      }
    }
    .navigationTitle("Vision Pro")
  }
}

#Preview {
  NavigationSplitView {
    SidebarView(selection: .constant("media"))
  } detail: {
    Text("Select a category")
  }
}
