import SwiftUI

struct ScenesGridView: View {
  let scenes: [StashScene]

  private let columns = [
    GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 20) {
      ForEach(scenes) { scene in
        SceneRow(scene: scene, allScenes: scenes)
      }
    }
    .padding()
  }
}

struct MarkersGridView: View {
  let markers: [SceneMarker]
  @EnvironmentObject private var navigationModel: NavigationModel

  private let columns = [
    GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 20) {
      ForEach(markers) { marker in
        MarkerRow(
          marker: marker,
          isPreviewVisible: true,
          onTagSelected: { _ in }  // No-op since we don't need tag filtering in this view
        )
      }
    }
    .padding()
  }
}

struct MarkersGridView_Previews: PreviewProvider {
  static var previews: some View {
    MarkersGridView(markers: [SceneMarker.example])
      .environmentObject(NavigationModel())

  }
}
