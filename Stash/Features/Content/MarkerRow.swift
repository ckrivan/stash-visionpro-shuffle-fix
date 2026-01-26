import AVKit
import SwiftUI

// Class to handle KVO observations that extends NSObject
class PlayerItemObserver: NSObject {
  var streamAttempts = 0
  var onStreamingToggle: ((Bool) -> Void)?
  var onBufferEmpty: (() -> Void)?

  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "playbackLikelyToKeepUp" {
      if let item = object as? AVPlayerItem, !item.isPlaybackLikelyToKeepUp {
        print("⚠️ Playback not likely to keep up - buffer issues")
        // Natural recovery will happen
      }
    } else if keyPath == "playbackBufferEmpty" {
      if let item = object as? AVPlayerItem, item.isPlaybackBufferEmpty {
        print("⚠️ Playback buffer empty")
        onBufferEmpty?()
      }
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }
}

struct MarkerRow: View {
  let marker: SceneMarker
  let isPreviewVisible: Bool
  let onTagSelected: (StashScene.Tag) -> Void
  @StateObject private var api = StashAPI()
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel
  @StateObject private var playerManager = VideoPlayerManager()  // Use the same player manager for HLS options
  @State private var player: AVPlayer?  // Declare the player state here
  @State private var isLoadingScene = false
  @State private var isPreviewPlaying = false  // Track if preview is actively playing
  @State private var streamAttempts = 0  // Track streaming attempts
  @State private var showStreamingOptions = false

  // Object to handle KVO observations
  private let playerObserver = PlayerItemObserver()

  // Stream URL with API key directly embedded for easier access
  private var streamURL: URL? {
    if playerManager.useHLS {
      // Use HLS streaming
      // Handle both cases: whether stream already ends with '/stream' or not
      let baseURL: String
      if marker.stream.hasSuffix("/stream") {
        baseURL = marker.stream.replacingOccurrences(of: "/stream", with: "/stream.m3u8")
      } else {
        // If it doesn't end with "/stream", just append ".m3u8"
        baseURL = "\(marker.stream).m3u8"
      }
      return URL(string: "\(baseURL)?apikey=\(api.apiKey)&resolution=ORIGINAL")
    } else {
      // Use direct streaming
      return URL(string: "\(marker.stream)?apikey=\(api.apiKey)")
    }
  }

  // Extract the video player into a separate view
  private var videoPlayerView: some View {
    // Only create if we have a URL
    Group {
      if let url = streamURL, isPreviewVisible && isPreviewPlaying {
        ZStack {
          // Video player without controls or dimming
          VideoPlayer(player: player)
            .aspectRatio(16 / 9, contentMode: .fill)
            .allowsHitTesting(false)

          // Custom overlay to prevent darkening and to detect taps
          Rectangle()
            .fill(Color.black.opacity(0.001))  // Nearly invisible but prevents darkening
            .contentShape(Rectangle())

          // Streaming mode indicator (small badge in corner)
          VStack {
            HStack {
              Spacer()

              Text(playerManager.useHLS ? "HLS" : "Direct")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                  Capsule()
                    .fill(
                      playerManager.useHLS ? Color.blue.opacity(0.6) : Color.purple.opacity(0.6))
                )
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
            }
            Spacer()
          }
          .padding(8)
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .frame(minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
          print("🔍 MarkerRow VideoPlayer - OnAppear with stream URL: \(url)")
          if player == nil {
            setupPreviewPlayer(videoURL: url)
          }
          // Start playback since we're in playing mode
          player?.play()
        }
        .onDisappear {
          cleanupPlayer()
        }
        .overlay {
          if isLoadingScene {
            ProgressView()
              .scaleEffect(2.0)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(.black.opacity(0.5))
          }
        }
        .transition(AnyTransition.opacity)
      }
    }
  }

  // Extract media container into a separate view
  private var mediaContainerView: some View {
    ZStack {
      // Always show the thumbnail in the background
      thumbnailView
        .opacity(isPreviewPlaying && isPreviewVisible ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: isPreviewPlaying)

      // Show video player on top when actively playing
      videoPlayerView
    }
    .animation(.easeInOut(duration: 0.3), value: isPreviewPlaying)
    .onTapGesture {
      handleTap()
    }
    .onLongPressGesture {
      playFullScene()
    }
  }

  // Handle the tap gesture to open full scene instead of preview
  private func handleTap() {
    // Reset streaming options view if shown
    if showStreamingOptions {
      showStreamingOptions = false
      streamAttempts = 0
      return
    }

    // Open full scene when tapped (instead of preview)
    print("🔍 MarkerRow - Tapped marker: \(marker.id) - Opening full scene")
    playFullScene()
  }

  // Extract content info into a separate view
  private var contentInfoView: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Title
      Button(action: playFullScene) {
        Text(marker.title)
          .font(.headline)
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .hoverEffect(.highlight)

      if let scene = marker.scene {
        Text(scene.title)
          .font(.subheadline)
          .foregroundStyle(.secondary)

        // Marker info
        tagsView

        // Display performers
        FetchPerformersView(scene: scene)
      }
    }
    .padding(16)
  }

  // Extract tags view for further simplification
  private var tagsView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        Text(marker.formattedTime)
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.secondary.opacity(0.2))
          .clipShape(Capsule())

        if let primaryTag = marker.primary_tag {
          Button(action: { onTagSelected(primaryTag) }) {
            Text(primaryTag.name)
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.blue.opacity(0.2))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .hoverEffect(.highlight)
        }

        if let tags = marker.tags {
          ForEach(tags) { tag in
            Button(action: { onTagSelected(tag) }) {
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
    }
    .scrollClipDisabled()
  }

  // Main body is now much simpler
  var body: some View {
    VStack(alignment: .leading) {
      // Media container (thumbnail/video)
      mediaContainerView

      // Content information
      contentInfoView
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .hoverEffect(.lift)
  }

  private func setupPreviewPlayer(videoURL: URL) {
    print("🔍 MarkerRow setupPreviewPlayer - Setting up player with URL: \(videoURL)")
    print("🔍 Using \(playerManager.useHLS ? "HLS" : "direct") streaming mode")

    // Debug logging to help diagnose URL issues
    if playerManager.useHLS && !videoURL.absoluteString.contains("m3u8") {
      print("⚠️ Warning: HLS mode is enabled but URL does not contain m3u8: \(videoURL)")
    }

    self.streamAttempts += 1

    // Set up asset with required headers and improved settings
    var headers = [
      "Accept": "*/*",
      "Accept-Language": "en-US,en;q=0.9",
      "Connection": "keep-alive",
      "User-Agent": "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15",
      "X-Playback-Session-Id": UUID().uuidString,
      "ApiKey": api.apiKey,
      "Authorization": "Bearer \(api.apiKey)"
    ]

    // For direct streaming, use identity encoding
    if !playerManager.useHLS {
      headers["Accept-Encoding"] = "identity"
    }

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

    let asset = AVURLAsset(url: videoURL, options: assetOptions)
    let playerItem = AVPlayerItem(asset: asset)

    // Configure for optimal streaming
    playerItem.preferredForwardBufferDuration = 10
    playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

    // Create new player with enhanced configuration
    let newPlayer = AVPlayer(playerItem: playerItem)
    newPlayer.automaticallyWaitsToMinimizeStalling = !playerManager.useHLS  // Enable for direct, disable for HLS
    newPlayer.isMuted = true

    // Store the player in state
    self.player = newPlayer
    print("🔍 MarkerRow setupPreviewPlayer - Player created and configured")

    // Register with global manager for full cleanup support
    GlobalVideoManager.shared.registerPlayer(newPlayer)

    // Observe status changes to detect failures
    let statusObserver = playerItem.observe(\.status) { item, _ in
      DispatchQueue.main.async {
        switch item.status {
        case .readyToPlay:
          print("✅ Marker preview player ready to play")
          // Success! Reset attempt counter
          self.streamAttempts = 0

        case .failed:
          print("❌ Marker preview player failed: \(String(describing: item.error))")

          // Get detailed error information
          if let itemError = item.error as NSError? {
            print("❌ Error domain: \(itemError.domain)")
            print("❌ Error code: \(itemError.code)")

            // If this is the Cannot Open error (-11828) with NSOSStatusErrorDomain (-12847)
            if itemError.domain == AVFoundationErrorDomain && itemError.code == -11828,
              let underlyingError = itemError.userInfo[NSUnderlyingErrorKey] as? NSError,
              underlyingError.domain == "NSOSStatusErrorDomain" && underlyingError.code == -12847 {
              // Auto-toggle streaming method if we haven't tried too many times
              if self.streamAttempts < 3 {
                print("🔄 Auto-toggling streaming mode due to Cannot Open error")
                self.cleanupPlayer()

                // Toggle HLS mode
                self.playerManager.useHLS.toggle()

                // Retry with new streaming mode if still visible
                if self.isPreviewVisible && self.isPreviewPlaying, let newURL = self.streamURL {
                  print("🔄 Retrying with \(self.playerManager.useHLS ? "HLS" : "direct") streaming")
                  self.setupPreviewPlayer(videoURL: newURL)
                  self.player?.play()
                }
              } else {
                // Too many attempts, show streaming options toggle
                print("⚠️ Too many streaming attempts, showing options toggle")
                self.showStreamingOptions = true
              }
            } else {
              // For other errors, also try the alternate streaming method if we haven't exceeded attempts
              if self.streamAttempts < 3 {
                print(
                  "🔄 Trying alternate streaming method due to error: \(itemError.localizedDescription)"
                )
                self.cleanupPlayer()

                // Toggle HLS mode
                self.playerManager.useHLS.toggle()

                // Retry with new streaming mode if still visible
                if self.isPreviewVisible && self.isPreviewPlaying, let newURL = self.streamURL {
                  print("🔄 Retrying with \(self.playerManager.useHLS ? "HLS" : "direct") streaming")
                  self.setupPreviewPlayer(videoURL: newURL)
                  self.player?.play()
                }
              } else {
                // Too many attempts, show streaming options toggle
                print("⚠️ Too many streaming attempts, showing options toggle")
                self.showStreamingOptions = true
              }
            }
          }

        case .unknown:
          print("⚠️ Marker preview player status unknown")

        @unknown default:
          break
        }
      }
    }

    // Store observer to prevent it from being deallocated
    playerItem.accessibilityElements = [statusObserver]

    // Add failure notification observer
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { notification in
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        print("❌ Player failed to play to end: \(error.localizedDescription)")

        DispatchQueue.main.async {
          // Only toggle if we haven't tried too many times
          if self.streamAttempts < 3 {
            print("🔄 Auto-toggling streaming mode due to playback failure")
            self.cleanupPlayer()

            // Toggle HLS mode
            self.playerManager.useHLS.toggle()

            // Retry with new streaming mode if still visible
            if self.isPreviewVisible && self.isPreviewPlaying, let newURL = self.streamURL {
              print("🔄 Retrying with \(self.playerManager.useHLS ? "HLS" : "direct") streaming")
              self.setupPreviewPlayer(videoURL: newURL)
              self.player?.play()
            }
          } else {
            // Too many attempts, show streaming options toggle
            print("⚠️ Too many streaming attempts, showing options toggle")
            self.showStreamingOptions = true
          }
        }
      }
    }

    // Monitor for buffering issues using the observer class
    let playbackLikelyToKeepUpContext = UnsafeMutableRawPointer(bitPattern: 1)
    let playbackBufferEmptyContext = UnsafeMutableRawPointer(bitPattern: 2)

    playerObserver.onBufferEmpty = { [weak newPlayer] in
      guard let player = newPlayer else { return }

      // If player is ready but buffer is empty, try to resume playback
      if player.status == .readyToPlay {
        DispatchQueue.main.async {
          player.play()
        }
      }
    }

    playerObserver.onStreamingToggle = { useHLS in
      DispatchQueue.main.async {
        self.playerManager.useHLS = useHLS

        // Retry with new streaming mode if still visible
        if self.isPreviewVisible && self.isPreviewPlaying, let newURL = self.streamURL {
          print("🔄 Retrying with \(self.playerManager.useHLS ? "HLS" : "direct") streaming")
          self.cleanupPlayer()
          self.setupPreviewPlayer(videoURL: newURL)
          self.player?.play()
        }
      }
    }

    playerItem.addObserver(
      playerObserver,
      forKeyPath: "playbackLikelyToKeepUp",
      options: [.new, .initial],
      context: playbackLikelyToKeepUpContext)

    playerItem.addObserver(
      playerObserver,
      forKeyPath: "playbackBufferEmpty",
      options: [.new, .initial],
      context: playbackBufferEmptyContext)

    // Add loop observer
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      // Use a direct reference to player
      DispatchQueue.main.async {
        self.player?.seek(to: .zero)
        self.player?.play()
      }
    }
  }

  private func cleanupPlayer() {
    if let player = player {
      // First pause and mute the player
      player.pause()
      player.isMuted = true
      player.volume = 0

      // Remove all observers from the player item to prevent memory leaks
      if let playerItem = player.currentItem {
        NotificationCenter.default.removeObserver(
          self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(
          self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)

        // Remove KVO observers with safety
        do {
          playerItem.removeObserver(playerObserver, forKeyPath: "playbackLikelyToKeepUp")
          playerItem.removeObserver(playerObserver, forKeyPath: "playbackBufferEmpty")
        } catch {
          print("⚠️ Warning: Failed to remove observers: \(error)")
        }
      }

      // Unregister from global manager
      GlobalVideoManager.shared.unregisterPlayer(player)

      // Set player item to nil to release all resources
      player.replaceCurrentItem(with: nil)
    }

    // Clear player reference
    player = nil

    print("🧹 Player resources cleaned up successfully")
  }

  // Extracted thumbnail view as a computed property
  private var thumbnailView: some View {
    ZStack {
      // Base thumbnail image
      AsyncImage(url: URL(string: "\(marker.screenshot)?apikey=\(api.apiKey)")) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(.ultraThinMaterial)
      }

      // Show streaming options toggle when we've had repeated failures
      if showStreamingOptions && isPreviewPlaying {
        VStack(spacing: 12) {
          Text("Streaming Issue")
            .font(.headline)
            .foregroundStyle(.white)

          Text("Try changing streaming mode")
            .font(.caption)
            .foregroundStyle(.white)

          VStack(spacing: 8) {
            Button(action: {
              // Toggle to HLS
              playerManager.useHLS = true
              showStreamingOptions = false
              streamAttempts = 0

              // Retry with HLS streaming
              if let url = streamURL {
                setupPreviewPlayer(videoURL: url)
                player?.play()
              }
            }) {
              HStack {
                Image(systemName: "network")
                Text("Try HLS")
              }
              .font(.caption)
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(Color.blue.opacity(0.7))
              .cornerRadius(8)
              .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: {
              // Toggle to Direct
              playerManager.useHLS = false
              showStreamingOptions = false
              streamAttempts = 0

              // Retry with direct streaming
              if let url = streamURL {
                setupPreviewPlayer(videoURL: url)
                player?.play()
              }
            }) {
              HStack {
                Image(systemName: "network")
                Text("Try Direct")
              }
              .font(.caption)
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(Color.purple.opacity(0.7))
              .cornerRadius(8)
              .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
      }

      // Show play indicator button when not playing
      if !isPreviewPlaying {
        Image(systemName: "play.circle.fill")
          .font(.system(size: 50))
          .foregroundStyle(.white.opacity(0.9))
          .shadow(color: .black.opacity(0.5), radius: 4)
      }
    }
    .aspectRatio(16 / 9, contentMode: .fill)
    .frame(minHeight: 180)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private func playFullScene() {
    if let scene = marker.scene {
      Task {
        isLoadingScene = true
        // Clean up preview player first
        cleanupPlayer()

        do {
          // Fetch the specific scene by ID
          print("🎬 Fetching scene details for ID: \(scene.id)")
          if let fullScene = try await api.fetchScene(byID: scene.id) {
            print("✅ Found full scene details for ID: \(scene.id)")

            // Create a new scene with the modified stream URL
            // Get performer info from scene if available
            let scenePerformers = scene.performers?.map { performerInfo in
              return StashScene.Performer(
                id: performerInfo.id,
                name: performerInfo.name,
                gender: nil,
                url: nil,
                twitter: nil,
                instagram: nil,
                image_path: performerInfo.image_path,
                scene_count: nil,
                image_count: nil,
                gallery_count: nil,
                rating100: nil,
                favorite: nil,
                country: nil,
                height_cm: nil,
                fake_tits: nil,
                career_length: nil,
                tattoos: nil,
                piercings: nil,
                aliases: nil,
                tags: nil,
                stash_ids: nil,
                created_at: nil,
                updated_at: nil,
                details: nil
              )
            }

            // Create scene from full data plus any additional marker-provided data
            let modifiedScene = StashScene(
              id: fullScene.id,
              title: fullScene.title,
              details: fullScene.details,
              url: fullScene.url,
              date: fullScene.date,
              rating100: fullScene.rating100,
              organized: fullScene.organized,
              oCounter: fullScene.oCounter,
              paths: StashScene.ScenePaths(
                screenshot: fullScene.paths.screenshot,
                preview: fullScene.paths.preview,
                stream: fullScene.paths.stream,
                webp: fullScene.paths.webp,
                vtt: fullScene.paths.vtt,
                sprite: fullScene.paths.sprite,
                funscript: fullScene.paths.funscript,
                interactive_heatmap: fullScene.paths.interactive_heatmap
              ),
              files: fullScene.files,
              performers: scenePerformers ?? fullScene.performers,
              tags: fullScene.tags,
              studio: fullScene.studio,
              stashIds: fullScene.stashIds,
              createdAt: fullScene.createdAt,
              updatedAt: fullScene.updatedAt
            )

            print(
              "🎬 Opening video player for scene: \(modifiedScene.id) at time: \(marker.seconds)")
            // Open the video player with the modified scene and start time
            await MainActor.run {
              appModel.selectedScene = modifiedScene
              appModel.selectedSceneStartTime = marker.seconds
              appModel.isShowingPlayer = true
            }
          } else {
            print("❌ Failed to find scene with ID: \(scene.id)")
          }
        } catch {
          print("❌ Error loading scene: \(error)")
        }

        isLoadingScene = false
      }
    }
  }
}

struct FetchPerformersView: View {
  let scene: SceneMarker.MarkerScene
  @StateObject private var api = StashAPI()
  @State private var performers: [StashScene.Performer] = []
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    Group {
      if !performers.isEmpty {
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
      } else {
        // Show loading or empty state
        Text("Loading performers...")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .task {
      print("🎬 Loading performers for scene: \(scene.id)")
      do {
        if let fullScene = try await api.fetchScene(byID: scene.id) {
          print("✅ Found scene: \(fullScene.title)")
          print("👥 Performers: \(fullScene.performers?.map { $0.name } ?? [])")
          await MainActor.run {
            performers = fullScene.performers ?? []
          }
        } else {
          print("❌ Failed to find scene with ID: \(scene.id)")
        }
      } catch {
        print("❌ Error loading scene: \(error)")
      }
    }
    // Pass navigationModel from the parent view
  }
}
