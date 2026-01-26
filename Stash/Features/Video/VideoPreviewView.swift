import AVKit
import RealityKit
import SwiftUI

struct VideoPreviewView: View {
    @EnvironmentObject var appModel: AppModel
    let scene: StashScene
  @State private var player: AVPlayer?
  @State private var showFullScreen = false
  @State private var isPreviewLoaded = false
  @Environment(\.openWindow) private var openWindow
  @StateObject private var api = StashAPI()

  var body: some View {
    ZStack {
      if let player = player {
        VideoPlayer(player: player)
          .controlSize(.mini)
          .onAppear {
            setupPreviewLoop()
          }
          .onDisappear {
            player.pause()
          }
          .onTapGesture {
            handleTap()
          }
          .overlay(alignment: .bottomTrailing) {
            if let file = scene.files?.first {
              Text(formatDuration(file.duration ?? 0))
                .font(.caption)
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
                .padding(8)
            }
          }
      } else {
        // Placeholder or thumbnail while video loads
        if let screenshotPath = scene.paths.screenshot,
          let screenshotURL = URL(string: "\(screenshotPath)?apikey=\(api.apiKey)") {
          AsyncImage(url: screenshotURL) { phase in
            switch phase {
            case .empty:
              ProgressView()
            case .success(let image):
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            case .failure:
              Color.gray
            @unknown default:
              Color.gray
            }
          }
        } else {
          Color.gray
        }
      }
    }
    .task {
      await loadPreviewPlayer()
    }
    .onChange(of: showFullScreen) { _, isShowing in
      if !isShowing {
        setupPreviewLoop()
      }
    }
  }

  private func loadPreviewPlayer() async {
    guard let previewPath = scene.paths.preview,
      let previewURL = URL(string: "\(previewPath)?apikey=\(api.apiKey)")
    else {
      return
    }

    print("🎬 Loading preview for URL: \(previewURL)")

    // Create AVPlayer with the preview URL
    let player = AVPlayer()
    let playerItem = AVPlayerItem(url: previewURL)

    // Configure player
    player.replaceCurrentItem(with: playerItem)
    player.isMuted = true
    player.actionAtItemEnd = .none  // Prevent playback from stopping at end

    // Add periodic time observer for looping
    let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
      // Check if we're near the end and loop if needed
      if let duration = player.currentItem?.duration,
        time
          >= CMTimeSubtract(
            duration, CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))) {
        player.seek(to: .zero)
      }
    }

    await MainActor.run {
      self.player = player
      player.play()
    }
  }

  private func setupPreviewLoop() {
    guard let player = player else { return }
    print("🎬 Setting up preview loop")
    player.seek(to: .zero)
    player.play()
  }

  private func handleTap() {
    player?.pause()  // Pause preview

    // Open full-screen player window
    if let streamPath = scene.paths.stream {
      appModel.setCurrentScene(scene, in: [scene])
      appModel.isShowingPlayer = true
    }
  }

  private func formatDuration(_ duration: Double) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) / 60 % 60
    let seconds = Int(duration) % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }
}

class VideoPlayerViewModel: NSObject, ObservableObject {
  @Published var player = AVPlayer()
  @Published var isPlaying = false
  @Published var isLoading = false
  @Published var error: String?

  private var timeObserver: Any?
  private var playerItem: AVPlayerItem?

  override init() {
    super.init()
    player.automaticallyWaitsToMinimizeStalling = true
    player.isMuted = true
  }

  func loadPreview(url: String) {
    guard let previewURL = URL(string: url) else {
      error = "Invalid preview URL"
      return
    }

    cleanup()
    isLoading = true

    var request = URLRequest(url: previewURL)
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

    let asset = AVURLAsset(url: previewURL)
    playerItem = AVPlayerItem(asset: asset)

    if let playerItem = playerItem {
      playerItem.addObserver(self, forKeyPath: "status", options: [], context: nil)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(playerItemDidReachEnd),
        name: .AVPlayerItemDidPlayToEndTime,
        object: playerItem
      )

      player.replaceCurrentItem(with: playerItem)
      player.play()
      isPlaying = true
    }
  }

  @objc private func playerItemDidReachEnd() {
    player.seek(to: .zero)
    player.play()
  }

  override public func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "status", let playerItem = object as? AVPlayerItem {
      DispatchQueue.main.async {
        switch playerItem.status {
        case .readyToPlay:
          self.isLoading = false
          self.error = nil
        case .failed:
          self.isLoading = false
          self.error = playerItem.error?.localizedDescription ?? "Failed to load preview"
        default:
          break
        }
      }
    }
  }

  func cleanup() {
    player.pause()

    if let playerItem = playerItem {
      playerItem.removeObserver(self, forKeyPath: "status")
      NotificationCenter.default.removeObserver(
        self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }

    if let observer = timeObserver {
      player.removeTimeObserver(observer)
      timeObserver = nil
    }

    player.replaceCurrentItem(with: nil)
    playerItem = nil
    isPlaying = false
    isLoading = false
    error = nil
  }

  deinit {
    cleanup()
  }
}

struct PreviewPlayerControllerRepresentable: UIViewControllerRepresentable {
  let player: AVPlayer

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = false
    controller.videoGravity = .resizeAspectFill
    return controller
  }

  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    uiViewController.player = player
  }
}
