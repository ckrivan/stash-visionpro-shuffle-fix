import AVKit
import RealityKit
import RealityKitContent
import SwiftUI

struct ScenesGrid: View {
  let scenes: [StashScene]
  let columns: [GridItem]
  let onTagSelected: (StashScene.Tag) -> Void
  let onPerformerSelected: (StashScene.Performer) -> Void
  let onSceneAppear: (StashScene) -> Void
  let onSceneUpdated: (StashScene) -> Void
  let isLoadingMore: Bool
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @EnvironmentObject private var appModel: AppModel
  @State private var isTransitioning = false

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(scenes) { scene in
          SceneRow(scene: scene)
            .frame(maxWidth: .infinity)
            .hoverEffect(.lift)
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
              handleSceneSelection(scene)
            }
            .onAppear {
              onSceneAppear(scene)
            }
        }

        if isLoadingMore {
          ProgressView()
            .gridCellColumns(columns.count)
            .padding()
            .controlSize(.large)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .scrollIndicators(.visible)
    .onChange(of: appModel.immersiveSpaceState) { _, newState in
      if newState == .closed {
        isTransitioning = false
      }
    }
  }

  private func handleSceneSelection(_ scene: StashScene) {
    appModel.setCurrentScene(scene, in: scenes)
    appModel.openScene(scene)
  }
}
