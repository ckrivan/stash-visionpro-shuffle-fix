import AVKit
import SwiftUI

struct ImmersiveVideoPlayer: View {
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel
  @Environment(\.dismiss) private var dismiss
  @State private var isLoading = true
  @State private var error: Error?

  private var scene: StashScene? { appModel.currentScene }

  // Updated to detect 180-degree videos
  private var isImmersiveVideo: Bool {
    // All videos in VR library are immersive
    true
  }

  var body: some View {
    if let scene = scene {
      if isImmersiveVideo {
        ImmersiveVideoScene()
          .environmentObject(navigationModel)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .ignoresSafeArea()
          .onDisappear {
            cleanup()
          }
      } else {
        VideoPlayerView(scene: scene)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .ignoresSafeArea()
          .onDisappear {
            cleanup()
          }
      }
    } else {
      Text("No video selected")
        .foregroundColor(.white)
    }
  }

  private func cleanup() {
    print(" [ImmersiveVideoPlayer] Cleaning up")
    dismiss()
  }
}

struct ImmersiveVideoPlayer_Previews: PreviewProvider {
  static var previews: some View {
    ImmersiveVideoPlayer()
      
      .environmentObject(NavigationModel())
  }
}
