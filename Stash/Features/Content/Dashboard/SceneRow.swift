import AVKit
import ObjectiveC
import SwiftUI

struct SceneRow: View {
  let scene: StashScene
  // Closure called when a tag is tapped
  var onTagSelected: ((StashScene.Tag) -> Void)?
  // Closure called when the scene is deleted
  var onDelete: ((String) -> Void)?
  @State private var isVisible = false
  @State private var isPreviewPlaying = false  // Track if preview is playing
  @State private var selectedPerformer: StashScene.Performer?
  @State private var isFullScreen = false
  @State private var player: AVPlayer?
  @State private var isShuffling = false
  @State private var showDeleteAlert = false
  @State private var previewLoaded = false
  @StateObject private var api = StashAPI()
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var navigationModel: NavigationModel

  private var previewURL: URL? {
    guard let previewPath = scene.paths.preview else { return nil }
    return URL(string: previewPath)
  }

  private var streamURL: URL? {
    guard let streamPath = scene.paths.stream else { return nil }
    return URL(string: streamPath)
  }

  var body: some View {
    VStack(alignment: .leading) {
      // Show either thumbnail or video preview in the same place
      ZStack {
        // Always show the thumbnail in the background
        thumbnailView
          .opacity(isPreviewPlaying ? 0 : 1)
          .animation(.easeInOut(duration: 0.3), value: isPreviewPlaying)

        // Show video player on top when actively playing - using preview URL
        if let url = previewURL, isPreviewPlaying {
          // Use exact same frame and sizing as the thumbnail
          ZStack {
            // Video player without controls or dimming
            VideoPlayer(player: player)
              .aspectRatio(16 / 9, contentMode: .fill)
              .allowsHitTesting(false)

            // Custom overlay to prevent darkening and to detect taps
            // The overlay completely blocks interaction with the video player
            Rectangle()
              .fill(Color.black.opacity(0.001))  // Nearly invisible but prevents darkening
              .contentShape(Rectangle())
          }
          // Use exact same sizing parameters as thumbnailView to ensure consistency
          .aspectRatio(16 / 9, contentMode: .fill)
          .frame(minHeight: 180)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .onAppear {
            if !previewLoaded {
              previewLoaded = true
              setupPreviewPlayer(previewURL: url)
            }
            // Start playback since we're in playing mode
            player?.play()
          }
          .onDisappear {
            player?.pause()
          }
          .transition(AnyTransition.opacity)
        }

        // Random Jump button overlay
        VStack {
          Spacer()
          HStack {
            Button {
              playRandomVideo()
            } label: {
              HStack {
                Image(systemName: "shuffle.circle.fill")
                Text("Random Jump")
              }
              .font(.caption.bold())
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.purple.opacity(0.8))
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .simultaneousGesture(
              LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                  showDeleteAlert = true
                }
            )
            .padding(12)
            Spacer()
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: isPreviewPlaying)
      .onTapGesture {
        // Toggle playback when tapped
        isPreviewPlaying.toggle()
        if isPreviewPlaying {
          // Ensure we stop any other preview videos first
          GlobalVideoManager.shared.stopAllPreviews()

          // Set up player if needed
          if player == nil, let previewURL = self.previewURL {
            setupPreviewPlayer(previewURL: previewURL)
            player?.play()
          } else {
            player?.play()
          }
        } else {
          // Completely stop the player, don't just pause it
          cleanupPlayer()
          print("🔇 Preview player fully stopped on toggle")
        }
      }
      .onLongPressGesture {
        // Enter full screen on long press of the thumbnail area
        isFullScreen = true
      }

      VStack(alignment: .leading, spacing: 8) {
        // Title
        Button(action: {
          isFullScreen = true
        }) {
          Text(scene.title ?? "Untitled")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)

        // File information
        SceneFileInfoView(files: scene.files)

        // Performers
        if let performers = scene.performers,
          !performers.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(performers) { performer in
                NavigationLink(value: Route.performer(performer)) {
                  Text(performer.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
              }
            }
          }
          .scrollClipDisabled()
        }

        // Tags (tappable)
        if let tags = scene.tags,
          !tags.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(tags) { tag in
                NavigationLink(value: Route.tag(tag)) {
                  Text(tag.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
              }
            }
          }
          .scrollClipDisabled()
        }
      }
      .padding(16)
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .onAppear {
      isVisible = true
    }
    .onDisappear {
      isVisible = false
      if isPreviewPlaying {
        // Stop preview when the row disappears
        cleanupPlayer()
        isPreviewPlaying = false
        previewLoaded = false
      }
    }
    .fullScreenCover(isPresented: $isFullScreen) {
      VideoPlayerView(scene: scene)
        .environmentObject(navigationModel)
    }
    .alert("Delete Scene?", isPresented: $showDeleteAlert) {
      Button("Delete", role: .destructive) {
        Task {
          do {
            try await api.deleteScene(id: scene.id)
            // Purge cached images and previews
            if let screenshot = scene.paths.screenshot, let url = URL(string: screenshot) {
              URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
            }
            if let preview = previewURL {
              URLCache.shared.removeCachedResponse(for: URLRequest(url: preview))
            }
            if let stream = streamURL {
              URLCache.shared.removeCachedResponse(for: URLRequest(url: stream))
            }
            onDelete?(scene.id)
          } catch {
            print("Error deleting scene: \(error)")
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  // MARK: - View Components

  private var thumbnailView: some View {
    ZStack {
      // Use a background color in case the screenshot doesn't load
      Color.black

      // Screenshot from server
      if let screenshotPath = scene.paths.screenshot,
        let url = URL(string: screenshotPath) {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .aspectRatio(16 / 9, contentMode: .fill)
    .frame(minHeight: 180)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  // Player setup and cleanup functions
  private func setupPreviewPlayer(previewURL: URL) {
    // Clean up any existing player first
    cleanupPlayer()

    // Log the URL being used
    print("🎬 SceneRow setting up preview player with URL: \(previewURL.absoluteString)")

    // Set up asset with required headers if needed
    let headers = [
      "Accept": "*/*",
      "Accept-Encoding": "identity",
      "Accept-Language": "en-US,en;q=0.9",
      "User-Agent": "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15",
      "Connection": "keep-alive",
      "X-Playback-Session-Id": UUID().uuidString
    ]

    // Enhanced asset options for better streaming
    let assetOptions: [String: Any] = [
      "AVURLAssetHTTPHeaderFieldsKey": headers,
      "AVURLAssetAllowsExpensiveNetworkAccess": true,
      "AVURLAssetAllowsConstrainedNetworkAccess": true,
      "AVURLAssetUsesNSURLSessionKey": true,
      "AVURLAssetPreferPreciseDurationAndTimingKey": true,
      "AVURLAssetHTTPMaximumConnectionsPerHostKey": NSNumber(value: 5),
      "AVURLAssetHTTPUserAgentKey": "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15"
    ]

    let asset = AVURLAsset(url: previewURL, options: assetOptions)

    let playerItem = AVPlayerItem(asset: asset)
    playerItem.preferredForwardBufferDuration = 10
    player = AVPlayer(playerItem: playerItem)
    player?.automaticallyWaitsToMinimizeStalling = true
    player?.isMuted = true  // Preview is muted by default

    // Register player with manager for global control
    if let player = player {
      GlobalVideoManager.shared.registerPlayer(player)
      // Always start playing immediately
      player.play()
    }

    // Add loop observer to continue playing in a loop
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak player] _ in
      player?.seek(to: .zero)
      // Continue playing when it reaches the end
      player?.play()
    }

    // Also observe status to auto-play when ready
    let observation = playerItem.observe(\AVPlayerItem.status) { item, _ in
      if item.status == .readyToPlay {
        DispatchQueue.main.async {
          self.player?.play()
        }
      }
    }
    // Keep observation alive
    objc_setAssociatedObject(
      playerItem, UnsafeRawPointer(bitPattern: 1)!, observation, .OBJC_ASSOCIATION_RETAIN)
  }

  private func cleanupPlayer() {
    if let player = player {
      // First pause and ensure volume is zero
      player.pause()
      player.volume = 0
      player.isMuted = true

      // Special trick to ensure playback fully stops: replace the item with nil
      // This is the key fix for preventing "ghost" muted audio from continuing
      player.replaceCurrentItem(with: nil)

      // Unregister from global manager
      GlobalVideoManager.shared.unregisterPlayer(player)

      // Remove all observers associated with this player
      NotificationCenter.default.removeObserver(
        self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

      print("🔇 Preview player completely stopped and cleaned up")
    }

    // Set player reference to nil to release memory
    player = nil
  }

  /// Ultra-fast random jump with minimal operations
  private func playRandomVideo() {
    // Prevent re-entry
    if isShuffling { return }
    isShuffling = true

    // Generate random position between 10% and 90% of the duration
    // Do this outside the task for parallel processing
    var startTime: Double = 0
    let sceneToPlay = scene

    if let duration = sceneToPlay.files?.first?.duration, duration > 10 {
      let minPos = max(10, duration * 0.1)
      let maxPos = min(duration - 20, duration * 0.9)
      startTime = Double.random(in: minPos...maxPos)
    }

    // Set defaults immediately
    UserDefaults.standard.set(startTime, forKey: "last_video_start_time")
    UserDefaults.standard.set(sceneToPlay.id, forKey: "last_scene_id")

    Task {
      do {
        // Clean any existing player in this view - the bare minimum cleanup
        cleanupPlayer()

        // Use the minimal reset that still works
        await MainActor.run {
          appModel.isShowingPlayer = false
          appModel.currentScene = nil
        }

        // Absolutely critical part - replace item with nil
        if let player = player {
          player.pause()
          player.replaceCurrentItem(with: nil)
        }

        // No delays at all!

        // Just show the new player - this is the key fix
        await MainActor.run {
          self.isFullScreen = true
        }
      } catch {
        print("❌ Error during random jump: \(error)")
      }

      isShuffling = false
    }
  }
}
