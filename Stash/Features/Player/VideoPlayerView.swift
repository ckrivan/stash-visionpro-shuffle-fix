import AVKit
import Combine
import ObjectiveC
import RealityKit
import SwiftUI

// Preference key for tracking scrubber size changes
struct ScrubberSizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

// NOTE: GlobalVideoManager is defined in PreviewPlayerManager.swift
// We're just adding a comment reference here to indicate it's used in this file

private class PlayerContainerView: UIView {
  weak var playerLayer: AVPlayerLayer?
  private var isSettingUp = false
  private var playerTimeControlStatusObserver: NSKeyValueObservation?
  // Track if we're currently in a layout operation
  private var isInLayoutOperation = false
  // Track size changes for debugging
  private var lastSize: CGSize = .zero

  override func layoutSubviews() {
    super.layoutSubviews()

    // Skip if we're already setting up the player
    guard !isSettingUp else { return }

    // Log size changes for debugging
    if lastSize != bounds.size {
      print("📏 PlayerContainerView size changed from \(lastSize) to \(bounds.size)")
      lastSize = bounds.size
    }

    // Set a flag to avoid recursive layout calls
    isInLayoutOperation = true

    // Use CATransaction to make layer changes simultaneously
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    CATransaction.setAnimationDuration(0)

    // Resize the player layer to fill the entire view bounds
    playerLayer?.frame = bounds

    // Force immediate layout update
    CATransaction.commit()

    // Clear layout flag
    isInLayoutOperation = false
  }

  func setupPlayer(_ player: AVPlayer?) {
    guard !isSettingUp else { return }
    isSettingUp = true

    // Remove existing player layer and observers
    cleanup()

    guard let player = player else {
      isSettingUp = false
      return
    }

    // Create player layer with specific configuration for visionOS
    let layer = AVPlayerLayer(player: player)
    layer.frame = bounds
    layer.videoGravity = .resizeAspect

    // Enable metal rendering for visionOS
    layer.drawsAsynchronously = true
    layer.needsDisplayOnBoundsChange = true
    layer.backgroundColor = UIColor.clear.cgColor  // Ensure background is clear

    // CRITICAL: Check video's pixel aspect ratio asynchronously
    if let asset = player.currentItem?.asset {
      Task {
        do {
          // Load video tracks using modern async API
          let tracks = try await asset.loadTracks(withMediaType: .video)
          guard let videoTrack = tracks.first else { return }

          // Load track properties
          let naturalSize = try await videoTrack.load(.naturalSize)
          let formatDescriptions = try await videoTrack.load(.formatDescriptions)

          // Get pixel aspect ratio from format descriptions
          if let formatDescription = formatDescriptions.first {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

            // Get pixel aspect ratio extension
            var pixelAspectRatioValue: CGFloat = 1.0
            if let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any],
               let pixelAspectRatioDict = extensions["CVPixelAspectRatio"] as? [String: Any],
               let hSpacing = pixelAspectRatioDict["HorizontalSpacing"] as? Int,
               let vSpacing = pixelAspectRatioDict["VerticalSpacing"] as? Int,
               vSpacing > 0 {
              pixelAspectRatioValue = CGFloat(hSpacing) / CGFloat(vSpacing)
            }

            print("🎬 Video metadata:")
            print("  - Storage size: \(dimensions.width)x\(dimensions.height)")
            print("  - Natural size: \(naturalSize)")
            print("  - Pixel aspect ratio value: \(pixelAspectRatioValue)")

            // If pixels are non-square, AVPlayerLayer should handle it automatically
            // but we'll log it for debugging
            if pixelAspectRatioValue != 1.0 {
              let displayWidth = CGFloat(dimensions.width) * pixelAspectRatioValue
              let displayRatio = displayWidth / CGFloat(dimensions.height)
              print("  ⚠️ Non-square pixels detected!")
              print("  - Display size should be: \(Int(displayWidth))x\(dimensions.height)")
              print("  - Display aspect ratio: \(String(format: "%.3f", displayRatio))")
            }
          }
        } catch {
          print("❌ Error loading video metadata: \(error)")
        }
      }
    }

    // Add debug info
    print("🎬 Player layer configuration:")
    print("  - Frame: \(layer.frame)")
    print("  - Video gravity: \(layer.videoGravity)")
    print("  - Draws asynchronously: \(layer.drawsAsynchronously)")
    print("  - Has background color: \(layer.backgroundColor != nil)")

    // CRITICAL: Add notification observer for black screen detection
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("CheckVideoRenderingStatus"),
      object: nil,
      queue: .main
    ) { [weak self, weak layer] _ in
      guard let self = self, let layer = layer else { return }
      print("🖼️ BLACK SCREEN CHECK: Video layer info:")
      print("  - Layer frame: \(layer.frame)")
      print("  - Layer is hidden: \(layer.isHidden)")
      print("  - Layer opacity: \(layer.opacity)")
      print("  - Layer has content: \(layer.contents != nil)")
      // Force layer redraw
      layer.setNeedsDisplay()
    }

    // Add player layer to view
    self.layer.addSublayer(layer)
    self.playerLayer = layer

    // Add additional black screen debug reporting
    print("🖼️ VIDEO RENDER: Added player layer to view hierarchy")
    print("  - Layer bounds: \(self.bounds)")
    print("  - View background: \(self.backgroundColor?.description ?? "nil")")

    // Observe player status
    playerTimeControlStatusObserver = player.observe(\.timeControlStatus) { [weak self] player, _ in
      guard let self = self else { return }
      switch player.timeControlStatus {
      case .playing:
        print("▶️ Player is playing")
      case .paused:
        print("⏸️ Player is paused")
      case .waitingToPlayAtSpecifiedRate:
        print("⏳ Player is waiting to play")
      @unknown default:
        break
      }
    }

    isSettingUp = false
  }

  func cleanup() {
    playerTimeControlStatusObserver?.invalidate()
    playerTimeControlStatusObserver = nil
    playerLayer?.removeFromSuperlayer()
    playerLayer = nil
  }

  deinit {
    cleanup()
  }
}

private struct VideoPlayerUIView: UIViewRepresentable {
  let player: AVPlayer

  func makeUIView(context: Context) -> PlayerContainerView {
    print("🎬 Creating video player view")
    let view = PlayerContainerView()
    view.backgroundColor = .black

    // Setup black screen recovery notification handler
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("BlackScreenRecoveryRequest"),
      object: nil,
      queue: .main
    ) { [weak view] _ in
      guard let view = view else { return }
      print("🖼️ BLACK SCREEN RECOVERY: Received request in UI view")

      // Force video layer refresh
      if let layer = view.playerLayer {
        layer.setNeedsDisplay()
        print("🖼️ BLACK SCREEN RECOVERY: Forcing player layer redraw")

        // Add extra debug
        print(
          "🖼️ Player layer info: frame=\(layer.frame), hidden=\(layer.isHidden), opacity=\(layer.opacity)"
        )

        // More aggressive recovery
        let outerDeadline = DispatchTime.now() + 0.3
        let outerWorkItem = DispatchWorkItem { [weak layer] in
          guard let layer = layer else { return }
          layer.opacity = 0

          let innerDeadline = DispatchTime.now() + 0.1
          let innerWorkItem = DispatchWorkItem { [weak layer] in
            guard let layer = layer else { return }
            layer.opacity = 1.0
            print("🖼️ BLACK SCREEN RECOVERY: Reset layer opacity")
          }
          DispatchQueue.main.asyncAfter(deadline: innerDeadline, execute: innerWorkItem)
        }
        DispatchQueue.main.asyncAfter(deadline: outerDeadline, execute: outerWorkItem)
      } else {
        print("⚠️ BLACK SCREEN RECOVERY: No player layer available to refresh")
      }
    }

    return view
  }

  func updateUIView(_ uiView: PlayerContainerView, context: Context) {
    if uiView.playerLayer?.player !== player {
      // Setup player on the container view - only once!
      print("🎬 Setting up player layer")
      Task { @MainActor in
        uiView.setupPlayer(player)
        // Force playback to start
        player.play()
        player.playImmediately(atRate: 1.0)

        /*
        // Add critical playback monitoring to detect complete failure
        // This runs 10 seconds after setup and checks if playback has progressed
        Task {
          try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
          // Get the current time to check if playback is working
          let currentTime = player.currentTime().seconds
          // Check if player is playing
          let isPlaying = player.timeControlStatus == .playing
          print("🔍 Player item status: \(player.currentItem?.status.rawValue ?? -1), error: \(player.currentItem?.error)")
        
          print(
            "🔍 10-second playback check: time=\(currentTime), playing=\(isPlaying ? "yes" : "no")")
        
          // If we're not playing after 10 seconds, that's a critical failure
          if !isPlaying {
            print("⚠️ CRITICAL: Video didn't start playing after 10 seconds")
        
            // First check if we have video track issues (black screen with audio)
            if let playerItem = player.currentItem,
              let tracks = playerItem.tracks as? [AVPlayerItemTrack]
            {
              print("🎥 CRITICAL FAILURE - Checking video tracks:")
              var hasEnabledVideoTrack = false
        
              for (index, track) in tracks.enumerated() {
                let assetTrack = track.assetTrack
                let isEnabled = track.isEnabled
                let mediaType = assetTrack?.mediaType.rawValue ?? "unknown"
                print("  - Track \(index): type=\(mediaType), enabled=\(isEnabled)")
        
                if mediaType == "vide" && isEnabled {
                  hasEnabledVideoTrack = true
                }
        
                // Try to enable video tracks if they're disabled
                if mediaType == "vide" && !isEnabled {
                  track.isEnabled = true
                  print("🛠️ EMERGENCY FIX: Enabling disabled video track")
                }
              }
        
              if !hasEnabledVideoTrack {
                print("🛑 CRITICAL ISSUE: Video has no enabled video tracks")
              }
            }
        
            // Send notification to signal playback failure
            NotificationCenter.default.post(
              name: NSNotification.Name("VideoPlaybackFailure"),
              object: nil
            )
          }
        }
        */
      }
    }
  }

  // Required by UIViewRepresentable
  static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
    print("🎬 Cleaning up player view")
    Task { @MainActor in
      uiView.setupPlayer(nil)
    }
  }

  // Required by UIViewRepresentable
  func makeCoordinator() -> Coordinator {
    return Coordinator()
  }

  class Coordinator {}
}

struct VideoPlayerView: View {
  // Changed from let to @State to allow updating when videos change
  @State private var scene: StashScene
  @Environment(\.dismiss) var dismiss
  @StateObject private var playerManager = VideoPlayerManager()
  @State private var showControls = true
  @EnvironmentObject private var appModel: AppModel
  @State private var hideControlsTask: Task<Void, Never>?
  @State private var isShowingThumbnail = false
  @State private var thumbnailPosition: CGFloat = 0
  @State private var thumbnailImage: UIImage?
  @State private var thumbnailTime: Double = 0
  @State private var playerInitialized = false  // New flag to track proper init
  // Feedback overlay state
  @State private var feedbackMessage: String = ""
  @State private var showingFeedback = false
  // Track window size changes to avoid unintended dismissal
  @State private var currentWindowSize: CGSize = .zero
  @State private var isResizing = false
  @State private var resizeTimer: Timer?

  // Initialize with the provided scene
  init(scene: StashScene) {
    // Initialize the @State property using _scene
    _scene = State(initialValue: scene)
  }

  var body: some View {
    GeometryReader { geometry in
      // Handle window size changes
      ZStack {
        // Invisible view to detect size changes
        Color.clear
          .onChange(of: geometry.size) { oldSize, newSize in
            handleWindowSizeChange(from: oldSize, to: newSize)
          }

          // Add notification observer for player feedback
          .onAppear {
            NotificationCenter.default.addObserver(
              forName: NSNotification.Name("VideoPlayerFeedback"),
              object: nil,
              queue: .main
            ) { notification in
              // Extract message from notification
              if let message = notification.userInfo?["message"] as? String {
                showFeedback(message)
              }
            }

            // Allow external requests to reveal controls (e.g., black-screen timeout)
            NotificationCenter.default.addObserver(
              forName: NSNotification.Name("ShowControls"),
              object: nil,
              queue: .main
            ) { _ in
              withAnimation { showControls = true }
            }

            // CRITICAL: Setup player when view first appears
            print("🎬 VideoPlayerView onAppear - setting up player for scene: \(scene.id)")
            Task {
              await setupPlayer()
            }
          }
          .onDisappear {
            NotificationCenter.default.removeObserver(
              self,
              name: NSNotification.Name("VideoPlayerFeedback"),
              object: nil
            )
          }
          // CRITICAL: React to scene changes - this is the fix for the black screen shuffle issue
          .onChange(of: appModel.currentScene?.id) { oldSceneId, newSceneId in
            print(
              "🎬 VideoPlayerView detected scene change from \(oldSceneId ?? "nil") to \(newSceneId ?? "nil")"
            )

            if let newId = newSceneId, newId != scene.id {
              print("🎬 Scene changed - reinitializing player for new scene: \(newId)")

              // Update the local scene reference
              scene = appModel.currentScene ?? scene

              // Reset player state
              playerInitialized = false

              // Reinitialize player for new scene
              Task {
                await setupPlayer()
              }
            }
          }

        Color.black.ignoresSafeArea()

        if let player = playerManager.player {
          ZStack(alignment: .bottom) {
            // Main video view
            VideoPlayerUIView(player: player)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .edgesIgnoringSafeArea(.all)
            // Custom controls
            if showControls {
              VideoControlsView(
                playerManager: playerManager,
                player: player,
                showControls: showControls,
                geometry: geometry,
                onScrubbing: handleScrubbing,
                onScrubEnd: handleScrubEnd,
                showFeedback: showFeedback
              ) {
                withAnimation {
                  showControls = false
                }
              }
              // Enhanced hit testing area that adjusts with window size
              // Use multiple approaches for better touch detection
              .contentShape(Rectangle())
              .frame(height: min(300, geometry.size.height * 0.4))
              .position(
                x: geometry.size.width / 2,
                y: geometry.size.height - min(150, geometry.size.height * 0.2)
              )
              .zIndex(10)  // Ensure controls are above other elements
            }

            // Thumbnail overlay
            if isShowingThumbnail, let image = thumbnailImage {
              ThumbnailOverlayView(
                playerManager: playerManager,
                isShowingThumbnail: isShowingThumbnail,
                thumbnailImage: image,
                thumbnailTime: thumbnailTime,
                geometry: geometry
              )
              .allowsHitTesting(false)
            }

            // Custom buttons overlay at the top
            if showControls {
              VStack {
                VideoControlsOverlay(
                  playerManager: playerManager,
                  player: player,
                  playPureRandomVideo: handlePureRandomVideo,
                  playRandomVideo: handleRandomVideo,
                  playPerformerRandomVideo: handlePerformerRandomVideo,
                  dismiss: handleDismiss
                )
                .padding(.top, 60)
                // Make sure all buttons are interactive
                .allowsHitTesting(true)

                Spacer()
              }
            }
            // Feedback overlay
            if showingFeedback {
              VStack {
                Text(feedbackMessage)
                  .font(.system(size: 22, weight: .medium))  // Reduced size dramatically
                  .foregroundColor(.white)
                  .padding(.vertical, 10)  // Reduced padding
                  .padding(.horizontal, 16)  // Reduced padding
                  .background(
                    RoundedRectangle(cornerRadius: 12)  // Smaller corners
                      .fill(Color.black.opacity(0.6))  // More transparent
                      .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 0)  // Less prominent shadow
                  )
              }
              .transition(.move(edge: .top).combined(with: .opacity))  // Slide in from top
              .frame(maxWidth: .infinity)
              .padding(.top, 20)  // Position at top with padding
              .allowsHitTesting(false)
            }
          }
        } else if playerManager.isLoading {
          ZStack {
            VideoLoadingView()

            // Always visible emergency close button in top-right corner
            VStack {
              HStack {
                Spacer()
                Button(action: {
                  handleDismiss()
                }) {
                  IconImage(name: "close", width: 42, height: 42, color: .white.opacity(0.8))
                    .shadow(color: .black, radius: 2)
                    .padding(20)
                }
                .buttonStyle(.plain)
              }
              Spacer()
            }
          }
        } else if let error = playerManager.error {
          ZStack {
            VideoErrorView(error: error)

            // Always visible emergency close button in top-right corner
            VStack {
              HStack {
                Spacer()
                Button(action: {
                  handleDismiss()
                }) {
                  IconImage(name: "close", width: 42, height: 42, color: .white.opacity(0.8))
                    .shadow(color: .black, radius: 2)
                    .padding(20)
                }
                .buttonStyle(.plain)
              }
              Spacer()
            }
          }
        }
      }
      // Add tap gesture for showing/hiding controls
      .onTapGesture {
        withAnimation {
          showControls.toggle()
        }
        Task {
          await scheduleControlsHide()
        }
      }
      // Add gesture recognizer for both skip (horizontal) and play/pause (vertical)
      .gesture(
        DragGesture(minimumDistance: 30)  // Increased threshold to avoid accidental activation
          .onEnded { value in
            // Calculate horizontal and vertical movement
            let dx = value.translation.width
            let dy = value.translation.height

            // Check if gesture is in the middle area of the screen - avoid progress bar area
            let middleThird = geometry.size.height / 3
            let isInMiddleArea =
              value.startLocation.y > middleThird && value.startLocation.y < (middleThird * 2)

            print("🔄 Detected drag gesture: dx=\(dx), dy=\(dy), isInMiddleArea=\(isInMiddleArea)")

            // Handle HORIZONTAL swipes for timeline navigation
            if isInMiddleArea && abs(dx) > abs(dy) && abs(dx) > 70 {  // Horizontal swipe
              let skipSeconds: Double
              let feedback: String
              if dx > 0 {
                skipSeconds = 60
                feedback = "▶▶ 60s"
              } else {
                skipSeconds = -10
                feedback = "◀◀ 10s"
              }
              let seekTime = max(
                0, min(playerManager.currentTime + skipSeconds, playerManager.duration))
              playerManager.seek(to: seekTime)
              showFeedback(feedback)

              print("⏩ Swipe gesture processed: \(feedback)")
            }
            // Handle VERTICAL swipes for play/pause
            else if abs(dy) > abs(dx) && abs(dy) > 70 {  // Vertical swipe
              if dy < 0 {  // Upward swipe - toggle play/pause
                let isPlaying = playerManager.player?.timeControlStatus == .playing

                if isPlaying {
                  // Pause
                  playerManager.player?.pause()
                  // No feedback needed
                  print("⏸️ Paused with UP gesture")
                } else {
                  // Play
                  playerManager.player?.play()
                  // No feedback needed
                  print("▶️ Playing with UP gesture")
                }
              }
            }
          }
      )
      // Add track status monitoring for black screen debugging
      .onAppear {
        // Intentionally left blank; placeholder for future monitoring hooks
      }
      // Add special gesture for scrubbing with magnification gesture (pinch)
      .gesture(
        MagnificationGesture(minimumScaleDelta: 0.01)
          .onChanged { value in
            // Use a logarithmic mapping for more intuitive control
            // Map magnification to timeline: 0.5 = start, 1.0 = middle, 2.0 = end
            let clampedValue = max(0.25, min(4.0, value))  // Reasonable bounds

            // Logarithmic mapping: log(0.25)=-1.386, log(1.0)=0, log(4.0)=1.386
            let logValue = log(clampedValue)
            let normalizedLog = (logValue + 1.386) / (2 * 1.386)  // Maps to 0-1
            let ratio = max(0, min(1.0, normalizedLog))

            let position = geometry.size.width * CGFloat(ratio)

            // Use custom method for pinch scrubbing
            handlePinchScrubbing(position: position, geometry: geometry)

            // Show controls during scrubbing
            withAnimation {
              showControls = true
            }

            print("🔍 Pinch scrubbing - scale: \(value), ratio: \(ratio), position: \(position)")
          }
          .onEnded { value in
            // Calculate final position using same logarithmic logic as onChanged
            let clampedValue = max(0.25, min(4.0, value))
            let logValue = log(clampedValue)
            let normalizedLog = (logValue + 1.386) / (2 * 1.386)
            let ratio = max(0, min(1.0, normalizedLog))
            let position = geometry.size.width * CGFloat(ratio)

            // Use custom method for finishing pinch scrubbing
            handlePinchScrubEnd(position: position, geometry: geometry)

            // Show feedback
            let time = playerManager.duration * Double(ratio)
            showFeedback("⏱ \(playerManager.formatTime(time))")

            print("✅ Pinch scrubbing ended at position: \(position)/\(geometry.size.width)")

            // Schedule controls to hide after a delay
            Task {
              await scheduleControlsHide()
            }
          }
      )
    }
    .edgesIgnoringSafeArea(.all)
    .navigationBarHidden(true)
    .statusBarHidden(true)
    .task {
      // Set up black screen timeout callback
      playerManager.setBlackScreenTimeoutCallback {
        // Show controls and feedback instead of auto-shuffling
        print("🚨 Black screen timeout triggered — showing controls")
        NotificationCenter.default.post(
          name: NSNotification.Name("VideoPlayerFeedback"),
          object: nil,
          userInfo: ["message": "Video slow to start"]
        )
        NotificationCenter.default.post(name: NSNotification.Name("ShowControls"), object: nil)
      }

      await setupPlayer()
    }
    .onDisappear {
      cleanup()
    }
  }

  // Handle scrubbing during pinch gesture
  private func handlePinchScrubbing(position: CGFloat, geometry: GeometryProxy) {
    // Calculate relative position in the timeline
    let ratio = position / geometry.size.width
    let time = playerManager.duration * Double(ratio)
    thumbnailTime = time

    // Show thumbnail at the position
    Task {
      await loadThumbnailAtTime(time)
    }

    // Show thumbnail
    withAnimation(.easeIn(duration: 0.1)) {
      isShowingThumbnail = true
    }

    print("🔄 Pinch scrubbing at position: \(position), ratio: \(ratio), time: \(time)")
  }

  // Handle end of pinch scrubbing
  private func handlePinchScrubEnd(position: CGFloat, geometry: GeometryProxy) {
    // Calculate final position in timeline
    let ratio = position / geometry.size.width
    let time = min(max(0, playerManager.duration * Double(ratio)), playerManager.duration)

    // Seek to that position
    playerManager.seek(to: time)

    print("✅ Pinch scrub ended at position: \(position), ratio: \(ratio), time: \(time)")

    // Hide thumbnail after a short delay
    let deadline = DispatchTime.now() + 0.5
    let workItem = DispatchWorkItem {
      withAnimation(.easeOut(duration: 0.2)) {
        isShowingThumbnail = false
      }
    }
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
  }

  /// Attempts playback with multiple HLS resolutions for better compatibility
  /// - Parameter scene: The scene to play
  /// - Returns: True if any of the attempts successfully started playing
  private func attemptPlaybackWithHLSFallbacks(scene: StashScene) async -> Bool {
    print("🎬 Attempting adaptive HLS streaming with multiple resolutions")

    // Check if we're dealing with a video that might need transcoding
    // Check for problematic codecs like WMV (Windows Media) or HEVC
    let needsTranscoding =
      scene.files?.contains { file in
        let codec = file.video_codec?.lowercased() ?? ""
        return codec.contains("wmv") || codec.contains("msmpeg") || codec.contains("vc-1")
          || codec.contains("hevc") || codec.contains("h265") || codec.contains("h.265")
      } ?? false

    if needsTranscoding {
      print("🎬 Problematic codec detected (WMV/HEVC) - using optimized transcoding settings")

      // Try different resolutions in order of preference
      for resolution in ["720p", "480p", "240p"] {
        print("🎬 Trying HLS with \(resolution) resolution")

        // Force HLS mode
        playerManager.useHLS = true

        // Get transcoded URL with specific resolution
        if let transcodedURL = playerManager.api.getTranscodedHLSStreamURL(
          forSceneID: scene.id,
          resolution: resolution
        ) {
          // Create request and attempt playback
          var request = URLRequest(url: transcodedURL)
          request.setValue("application/vnd.apple.mpegurl, */*;q=0.8", forHTTPHeaderField: "Accept")

          // Try to start playing with this resolution
          if await startPlayback(with: request, scene: scene) {
            print("✅ Successfully playing with \(resolution) transcoded HLS stream")
            return true
          }

          print("⚠️ Failed with \(resolution) - trying next resolution")
        }
      }

      print("❌ All transcoded resolutions failed")
      return false
    } else {
      print("🎬 Not an HEVC video - using standard HLS")
      return false
    }
  }

  private func startPlayback(with request: URLRequest, scene: StashScene) async -> Bool {
    // Create a player item
    let playerItem = AVPlayerItem(url: request.url!)

    // Set up the player
    let player = AVPlayer(playerItem: playerItem)
    playerManager.player = player

    // Wait for playback to start or fail
    for _ in 0..<30 {  // Try for 3 seconds
      if player.timeControlStatus == .playing {
        return true
      }
      try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
    }

    return false
  }

  private func setupPlayer() async {
    // Make sure we don't run this more than once - this is critical
    if playerInitialized {
      print("⚠️ Player already initialized, skipping duplicate initialization")
      return
    }

    // Print detailed debug info for the current scene to help diagnose issues
    print("📋 Starting detailed scene debug for VTT/sprite troubleshooting")
    printSceneDebugInfo(scene)

    // Force reset the playerManager's sprite and VTT data to prevent cached data from previous videos
    await MainActor.run {
      // Clear previous sprites and VTT data to ensure we get fresh data for this video
      playerManager.spriteSheetImage = nil
      playerManager.vttEntries.removeAll()
      print("🧹 Cleared cached sprite and VTT data for new video")
    }

    // Mark as initialized immediately to prevent duplicates
    playerInitialized = true

    // Determine the correct start time with minimal checks
    var startTime = appModel.videoStartTime
    print(
      "🎯 VideoPlayerView.setupPlayer() - Reading start time from appModel.videoStartTime: \(startTime)"
    )
    print(
      "🎯 VideoPlayerView.setupPlayer() - appModel.selectedSceneStartTime: \(appModel.selectedSceneStartTime?.description ?? "nil")"
    )

    // Quick check for app model start time
    if startTime == 0 && appModel.selectedSceneStartTime != nil {
      startTime = appModel.selectedSceneStartTime!
      print("🎯 VideoPlayerView.setupPlayer() - Using selectedSceneStartTime: \(startTime)")
    }

    // Check UserDefaults only if needed
    if startTime == 0 {
      let savedStartTime = UserDefaults.standard.double(forKey: "last_video_start_time")
      let savedSceneId = UserDefaults.standard.string(forKey: "last_scene_id")
      print(
        "🎯 VideoPlayerView.setupPlayer() - UserDefaults savedStartTime: \(savedStartTime), savedSceneId: \(savedSceneId ?? "nil")"
      )

      if let savedId = savedSceneId, savedId == scene.id, savedStartTime > 0 {
        startTime = savedStartTime
        print("🎯 VideoPlayerView.setupPlayer() - Using UserDefaults savedStartTime: \(startTime)")
      }
    }

    print("🎯 VideoPlayerView.setupPlayer() - Final startTime to be used: \(startTime)")
    print(
      "🎯 VideoPlayerView.setupPlayer() - About to call playerManager.setupPlayer with startTime: \(startTime > 0 ? startTime : 0)"
    )

    // Improved audio setup with better error handling
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
      print("✅ Audio session setup complete")
    } catch {
      print("⚠️ Error setting up audio session: \(error)")
    }

    // Try multiple times with fallback strategy
    var attempts = 0
    var success = false

    while attempts < 3 && !success {
      attempts += 1

      do {
        // Add a small delay between retry attempts
        if attempts > 1 {
          try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
          print("🔄 Retry attempt #\(attempts) for video playback")
        }

        // Try to set up the player
        await playerManager.setupPlayer(for: scene, startTime: startTime > 0 ? startTime : nil)

        // If no error was thrown, consider it a success
        success = playerManager.player != nil && playerManager.error == nil

        if success {
          print("✅ Player setup successful on attempt #\(attempts)")
        }
      } catch {
        print("❌ Player setup failed on attempt #\(attempts): \(error.localizedDescription)")

        // Clean up resources before retry
        playerManager.cleanup()

        // Reset the audio session
        do {
          try AVAudioSession.sharedInstance().setActive(false)
          try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          print("⚠️ Audio session reset error: \(error)")
        }
      }
    }

    // Reset state immediately after
    appModel.selectedSceneStartTime = nil
    appModel.videoStartTime = 0
  }

  private func cleanup() {
    print("🎬 Starting CRITICAL CLEANUP process for video player")

    // Stage 1: Immediately stop all visual and UI updates
    hideControlsTask?.cancel()
    isShowingThumbnail = false
    thumbnailImage = nil

    // Stage 2: Kill all audio at system level
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print("⚠️ Error deactivating audio session: \(error)")
    }

    // Stage 3: Aggressive player cleanup through manager
    playerManager.cleanup()

    // Stage 4: Force the audio system to reset completely
    GlobalVideoManager.shared.forceStopAllAudio()

    // Stage 5: Remove any notification observers
    NotificationCenter.default.removeObserver(self)

    print("✅ Video player cleanup complete")
  }

  private func handlePureRandomVideo() {
    withAnimation(.easeOut(duration: 0.2)) {
      showControls = false
    }

    // Ensure current player is completely cleaned up first
    cleanup()

    // Reset initialized state to allow a new player to be created
    playerInitialized = false

    playPureRandomVideo()
  }

  private func handleRandomVideo() {
    withAnimation(.easeOut(duration: 0.2)) {
      showControls = false
    }

    // Ensure current player is completely cleaned up first
    cleanup()

    // Reset initialized state to allow a new player to be created
    playerInitialized = false

    playRandomVideo()
  }

  private func handlePerformerRandomVideo() {
    withAnimation(.easeOut(duration: 0.2)) {
      showControls = false
    }

    // Ensure current player is completely cleaned up first
    cleanup()

    // Reset initialized state to allow a new player to be created
    playerInitialized = false

    playPerformerRandomVideo()
  }

  private func handleDismiss() {
    print("🎬 Starting player dismissal sequence")

    // Cancel any pending resize timer to avoid conflicts
    resizeTimer?.invalidate()
    resizeTimer = nil

    // First clean up all player resources
    cleanup()

    // Post notification that player is being dismissed
    NotificationCenter.default.post(name: .init("DismissVideoPlayer"), object: nil)

    // Use longer delay and do another round of cleanup before dismissal
    let deadline = DispatchTime.now() + 0.3
    let workItem = DispatchWorkItem {
      // One last aggressive cleanup
      GlobalVideoManager.shared.forceStopAllAudio()

      // Reset audio session to ambient before dismissing
      do {
        try AVAudioSession.sharedInstance().setActive(false)
        try AVAudioSession.sharedInstance().setCategory(.ambient)
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("⚠️ Final audio session reset error: \(error)")
      }

      // Only dismiss if we're not currently resizing
      if !self.isResizing {
        // Finally dismiss the view
        self.dismiss()
      } else {
        print("⚠️ Prevented unintended dismissal during resize operation")
      }
    }
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
  }

  // Handler for window size changes
  private func handleWindowSizeChange(from oldSize: CGSize, to newSize: CGSize) {
    // Log size change for debugging
    print("📏 Window size changed from \(oldSize) to \(newSize)")

    // Skip if the size didn't actually change
    guard oldSize != newSize else { return }

    // Set resizing flag to prevent unintended dismissal
    isResizing = true

    // Debug check for tiny/large size changes which might indicate problematic resizing
    let widthChange = abs(oldSize.width - newSize.width)
    let heightChange = abs(oldSize.height - newSize.height)

    if widthChange > 200 || heightChange > 200 {
      print(
        "⚠️ Large window size change detected: width delta=\(widthChange), height delta=\(heightChange)"
      )
    }

    // Update the current window size
    currentWindowSize = newSize

    // Cancel any existing resize timer
    resizeTimer?.invalidate()

    // Use Task for debouncing instead of Timer to avoid capture issues with struct
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1))
      isResizing = false
      print("📏 Resize operation completed, player is now stable at size \(currentWindowSize)")
    }
  }

  private func scheduleControlsHide() async {
    hideControlsTask?.cancel()
    hideControlsTask = Task {
      do {
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        if !Task.isCancelled {
          try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))  // Animation duration
          if !Task.isCancelled {
            try await MainActor.run {
              showControls = false
            }
          }
        }
      } catch {
        // Task was cancelled
      }
    }
  }

  private func handleScrubbing(value: DragGesture.Value, geometry: GeometryProxy) {
    // Calculate position in timeline with bounds checking
    let position = max(0, min(value.location.x, geometry.size.width))
    thumbnailPosition = position

    // Calculate the ratio of scrubber position
    let scrubWidth = geometry.size.width
    let ratio = position / scrubWidth

    // Calculate time based on ratio
    let time = playerManager.duration * Double(ratio)
    thumbnailTime = time

    // Get thumbnail - with priority for VTT-based thumbnails
    Task {
      await loadThumbnailAtTime(time)
    }

    // Show thumbnail preview
    withAnimation(.easeIn(duration: 0.1)) {
      isShowingThumbnail = true
    }

    // DEBUG
    print("👆 Scrubbing at position: \(position), ratio: \(ratio), time: \(time)")
  }

  private func handleScrubEnd(value: DragGesture.Value, geometry: GeometryProxy) {
    // Calculate position in timeline with bounds checking
    let position = max(0, min(value.location.x, geometry.size.width))
    let scrubWidth = geometry.size.width
    let ratio = position / scrubWidth

    // Calculate time based on ratio with bounds checking
    let time = min(max(0, playerManager.duration * Double(ratio)), playerManager.duration)

    // Seek to position
    playerManager.seek(to: time)

    // DEBUG
    print("👆 Scrub ended at position: \(position), ratio: \(ratio), time: \(time)")

    // Hide thumbnail after a delay
    let deadline = DispatchTime.now() + 0.5
    let workItem = DispatchWorkItem {
      withAnimation(.easeOut(duration: 0.2)) {
        isShowingThumbnail = false
      }
    }
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
  }

  private func loadThumbnailAtTime(_ time: Double) async {
    // Three-tiered approach for thumbnail scrubbing

    // Method 1: Try VTT entries first (fastest and best quality)
    if await tryLoadThumbnailFromVTT(time: time) {
      return
    }

    // Method 2: Try direct screenshot API
    if await tryLoadThumbnailFromAPI(time: time) {
      return
    }

    // Method 3: Fall back to generating from the asset (slowest)
    await generateThumbnailFromAsset(time: time)
  }

  private func tryLoadThumbnailFromVTT(time: Double) async -> Bool {
    // Check if we have VTT entries
    if playerManager.vttEntries.isEmpty {
      print("ℹ️ No VTT entries available for thumbnail scrubbing")

      // Try to load VTT entries if they don't exist yet
      print("🔄 Attempting to load VTT entries using different approaches")

      // Try to get oshash from files
      if let fileInfo = await getFileInfo(forSceneID: scene.id) {
        print("📋 File info: \(fileInfo)")

        if let oshash = fileInfo["oshash"] as? String {
          print("📋 Found oshash: \(oshash)")

          // Try a direct HTTP access to the server files
          let directServerUrl = "http://192.168.86.100:9999/vtt/\(oshash)_thumbs.vtt"
          print("🔍 Trying direct VTT access via HTTP: \(directServerUrl)")

          if let httpUrl = URL(string: directServerUrl) {
            // Create a request with authentication
            var request = URLRequest(url: httpUrl)
            request.setValue(VideoPlayerUtility.apiKey, forHTTPHeaderField: "ApiKey")

            do {
              let (data, response) = try await URLSession.shared.data(for: request)
              if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                let content = String(data: data, encoding: .utf8),
                let entries = VideoPlayerUtility.parseVTTContent(content)
              {
                await MainActor.run {
                  playerManager.vttEntries = entries
                  print(
                    "✅ Successfully loaded \(entries.count) VTT entries from direct HTTP access")
                }
                return true
              } else {
                print("❌ HTTP VTT access failed or returned invalid data")
              }
            } catch {
              print("❌ Error with direct HTTP VTT access: \(error)")
            }
          }

          // First try local mounted path
          let localMountedPath = "/Volumes/vtt/\(oshash)_thumbs.vtt"
          let fileManager = FileManager.default

          if fileManager.fileExists(atPath: localMountedPath) {
            print("✅ Found local mounted VTT file: \(localMountedPath)")
            let localUrl = URL(fileURLWithPath: localMountedPath)

            // Try to parse the local VTT file
            if let content = try? String(contentsOf: localUrl) {
              if let entries = VideoPlayerUtility.parseVTTContent(content) {
                await MainActor.run {
                  playerManager.vttEntries = entries
                  print(
                    "✅ Successfully loaded \(entries.count) VTT entries from local mounted file")
                }
                return true
              } else {
                print("❌ Failed to parse content from local VTT file")
              }
            } else {
              print("❌ Failed to read content from local VTT file")
            }
          } else {
            print("❌ Local mounted VTT file not found: \(localMountedPath)")
          }

          // Try paths with oshash - use direct server path
          let oshashPaths = [
            // Full path to VTT file on server
            "/Users/mediaserver/.stash/generated/vtt/\(oshash)_thumbs.vtt"
          ]

          for oshashPath in oshashPaths {
            if let url = VideoPlayerUtility.createURL(path: oshashPath, includeApiKey: true) {
              print("🔑 Trying VTT path with oshash: \(url.absoluteString)")
              if let entries = await VideoPlayerUtility.parseVTT(from: url) {
                await MainActor.run {
                  playerManager.vttEntries = entries
                  print(
                    "✅ Successfully loaded \(entries.count) VTT entries using oshash: \(oshash)")
                }
                return true
              } else {
                print("❌ Failed to load VTT from oshash path: \(oshashPath)")
              }
            }
          }
        }
      }

      // We should only use the oshash approach as the scene ID is not used in the file naming
      print(
        "ℹ️ No VTT entries found with standard methods. Please ensure you have the correct oshash values."
      )

      // Print debugging info for clarity
      print(
        "🔍 VTT files should be in format: /Users/mediaserver/.stash/generated/vtt/{oshash}_thumbs.vtt"
      )
      print(
        "🔍 Sprite files should be in format: /Users/mediaserver/.stash/generated/vtt/{oshash}_sprite.jpg"
      )
      print("🔍 Where {oshash} is the file hash like '0a01a1125b031e3e'")

      // No fallback to scene ID as that doesn't follow Stash's naming pattern

      // If we still don't have entries after trying custom paths, return false
      if playerManager.vttEntries.isEmpty {
        return false
      }
    }

    // Find matching entry for this time
    guard
      let matchingEntry = playerManager.vttEntries.first(where: {
        time >= $0.startTime && time < $0.endTime
      })
    else {
      print("ℹ️ No matching VTT entry found for time \(time)")
      return false
    }

    print("🎬 Found VTT entry for time \(time): \(matchingEntry.startTime)-\(matchingEntry.endTime)")
    print(
      "🎬 Sprite coordinates: x=\(matchingEntry.x), y=\(matchingEntry.y), width=\(matchingEntry.width), height=\(matchingEntry.height)"
    )

    // Load sprite sheet if needed
    if playerManager.spriteSheetImage == nil {
      if let spriteUrl = VideoPlayerUtility.getSpriteURL(forSceneID: scene.id) {
        print("🔍 Loading sprite sheet from: \(spriteUrl.absoluteString)")
        do {
          let (data, _) = try await URLSession.shared.data(from: spriteUrl)
          if let spriteImage = UIImage(data: data) {
            await MainActor.run {
              playerManager.spriteSheetImage = spriteImage
              print("✅ Loaded sprite sheet: \(spriteImage.size.width)x\(spriteImage.size.height)")
            }
          } else {
            print("❌ Failed to decode sprite sheet image data")
            return false
          }
        } catch {
          print("❌ Error loading sprite sheet: \(error)")

          // Try alternative URL if primary fails
          if let alternativeUrl = VideoPlayerUtility.getAlternativeSpriteURL(forSceneID: scene.id) {
            print("🔍 Trying alternative sprite URL: \(alternativeUrl.absoluteString)")
            do {
              let (data, _) = try await URLSession.shared.data(from: alternativeUrl)
              if let spriteImage = UIImage(data: data) {
                await MainActor.run {
                  playerManager.spriteSheetImage = spriteImage
                  print(
                    "✅ Loaded sprite sheet from alternative URL: \(spriteImage.size.width)x\(spriteImage.size.height)"
                  )
                }
              } else {
                print("❌ Failed to decode alternative sprite sheet image data")
                return false
              }
            } catch {
              print("❌ Error loading alternative sprite sheet: \(error)")

              // Try to get oshash and load sprite directly
              if let fileInfo = await getFileInfo(forSceneID: scene.id),
                let oshash = fileInfo["oshash"] as? String
              {
                print("📋 Found oshash for sprite: \(oshash)")

                // First try local mounted path if available
                let localMountedPath = "/Volumes/vtt/\(oshash)_sprite.jpg"
                let fileManager = FileManager.default

                if fileManager.fileExists(atPath: localMountedPath) {
                  print("✅ Found local mounted sprite file: \(localMountedPath)")
                  if let spriteImage = UIImage(contentsOfFile: localMountedPath) {
                    await MainActor.run {
                      playerManager.spriteSheetImage = spriteImage
                      print(
                        "✅ Loaded sprite from local mount: \(spriteImage.size.width)x\(spriteImage.size.height)"
                      )
                    }
                    return true
                  } else {
                    print("❌ Failed to decode sprite from local mount")
                  }
                } else {
                  print("❌ Local mounted file not found: \(localMountedPath)")
                }

                // Try direct HTTP access to the sprite if local file wasn't found
                let directSpriteUrl = "http://192.168.86.100:9999/vtt/\(oshash)_sprite.jpg"
                print("🔍 Trying direct sprite HTTP access: \(directSpriteUrl)")

                if let httpSpriteUrl = URL(string: directSpriteUrl) {
                  do {
                    // Create authenticated request
                    var spriteRequest = URLRequest(url: httpSpriteUrl)
                    spriteRequest.setValue(VideoPlayerUtility.apiKey, forHTTPHeaderField: "ApiKey")

                    let (spriteData, spriteResponse) = try await URLSession.shared.data(
                      for: spriteRequest)
                    if let httpResponse = spriteResponse as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let spriteImage = UIImage(data: spriteData)
                    {
                      await MainActor.run {
                        playerManager.spriteSheetImage = spriteImage
                        print(
                          "✅ Loaded sprite from direct HTTP: \(spriteImage.size.width)x\(spriteImage.size.height)"
                        )
                      }
                      return true
                    }
                  } catch {
                    print("❌ Failed to load sprite via direct HTTP: \(error)")
                  }
                }

                // Fallback to regular paths
                let oshashSpritePaths = [
                  // Full absolute path for sprite
                  "/Users/mediaserver/.stash/generated/vtt/\(oshash)_sprite.jpg"
                ]

                for spritePath in oshashSpritePaths {
                  if let spriteOshashUrl = VideoPlayerUtility.createURL(
                    path: spritePath, includeApiKey: true)
                  {
                    print("🔍 Trying sprite with oshash: \(spriteOshashUrl.absoluteString)")
                    do {
                      let (oshashData, _) = try await URLSession.shared.data(from: spriteOshashUrl)
                      if let oshashSpriteImage = UIImage(data: oshashData) {
                        await MainActor.run {
                          playerManager.spriteSheetImage = oshashSpriteImage
                          print(
                            "✅ Loaded sprite sheet using oshash: \(oshashSpriteImage.size.width)x\(oshashSpriteImage.size.height)"
                          )
                        }
                        return true
                      }
                    } catch {
                      print("❌ Error loading sprite with oshash path \(spritePath): \(error)")
                    }
                  }
                }
              }

              print("❌ All sprite loading attempts failed")
              return false
            }
          } else {
            return false
          }
        }
      } else {
        print("❌ No sprite URL available for scene \(scene.id)")
        return false
      }
    }

    // Extract the thumbnail from the sprite sheet
    if let spriteImage = playerManager.spriteSheetImage {
      print(
        "🔍 Extracting thumbnail from sprite sheet at coordinates: x=\(matchingEntry.x), y=\(matchingEntry.y), width=\(matchingEntry.width), height=\(matchingEntry.height)"
      )

      // Ensure coordinates are valid for our sprite sheet
      let spriteWidth = Int(spriteImage.size.width)
      let spriteHeight = Int(spriteImage.size.height)

      // Validate coordinates against sprite sheet dimensions
      if matchingEntry.x < 0 || matchingEntry.y < 0
        || matchingEntry.x + matchingEntry.width > spriteWidth
        || matchingEntry.y + matchingEntry.height > spriteHeight
      {
        print(
          "⚠️ Invalid sprite coordinates for this sprite sheet. Sprite size: \(spriteWidth)x\(spriteHeight), Coordinates: x=\(matchingEntry.x), y=\(matchingEntry.y), width=\(matchingEntry.width), height=\(matchingEntry.height)"
        )
        return false
      }

      let rect = CGRect(
        x: matchingEntry.x, y: matchingEntry.y,
        width: matchingEntry.width, height: matchingEntry.height)

      if let cgImage = spriteImage.cgImage?.cropping(to: rect) {
        let thumbnail = UIImage(cgImage: cgImage)
        print("✅ Successfully extracted thumbnail from sprite sheet")
        await MainActor.run {
          thumbnailImage = thumbnail
        }
        return true
      } else {
        print("❌ Failed to crop sprite sheet image")
      }
    } else {
      print("❌ No sprite sheet image available")
    }

    return false
  }

  private func tryLoadThumbnailFromAPI(time: Double) async -> Bool {
    guard let url = VideoPlayerUtility.getThumbnailURL(forSceneID: scene.id, seconds: time) else {
      print("⚠️ No direct thumbnail URL available for scene \(scene.id) at time \(time)")
      return false
    }

    do {
      print("🎬 Loading thumbnail at time \(time) from direct API: \(url)")
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = UIImage(data: data) {
        await MainActor.run {
          thumbnailImage = image
        }
        return true
      }
    } catch {
      print("❌ Error loading Stash thumbnail: \(error)")
    }

    return false
  }

  private func generateThumbnailFromAsset(time: Double) async {
    print("🎬 Generating thumbnail from asset at time \(time)")
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
    await playerManager.generateThumbnail(at: cmTime) { image in
      if let image = image {
        Task { @MainActor in
          self.thumbnailImage = image
        }
      }
    }
  }

  // Pure random video (from beginning)
  private func playPureRandomVideo() {
    // Store the current HLS mode
    let wasUsingHLS = playerManager.useHLS

    // Stop any existing preview audio and clean up current player
    GlobalVideoManager.shared.muteAll()
    playerManager.cleanup()

    Task {
      // Show loading indicator instead of controls
      await MainActor.run {
        playerManager.isLoading = true
      }

      let api = StashAPI()
      // Fetch a random scene using the API's random sort
      do {
        try await api.fetchScenes(page: 1, sort: "random")

        // Filter out any scenes with VR tags
        let nonVRScenes = api.scenes.filter { !hasVRTag($0) }

        print(
          "🔍 Found \(api.scenes.count) random scenes, \(nonVRScenes.count) remain after filtering out VR content"
        )

        // Get the first scene from the filtered results
        if let randomScene = nonVRScenes.first {
          // Ensure we have the correct HLS mode
          if wasUsingHLS && !playerManager.useHLS {
            print("🎬 Explicitly setting HLS mode before player setup")
            playerManager.useHLS = true
          }

          // Set a flag to indicate we're in a shuffle operation
          await MainActor.run {
            appModel.videoStartTime = 0
            playerManager.isPerformingFallback = true
          }

          // Get performer information for the new scene - only first performer
          var performerName = "Unknown performer"
          if let performers = randomScene.performers, !performers.isEmpty {
            // Just take the first performer's name
            performerName = performers[0].name
            print("🎭 New scene features: \(performerName)")
          } else {
            print("🎭 New scene has no listed performers")
          }

          // Show feedback with the performer name
          showFeedback(performerName)

          // For pure random we always start from the beginning
          print("🎬 Setting up player with start from beginning")
          await playerManager.setupPlayer(for: randomScene, startTime: 0)

          // CRITICAL: Update the scene reference to the new scene
          // This ensures performer shuffle will use the correct performer
          await MainActor.run {
            self.scene = randomScene
            print("🎭 Updated scene reference to: \(randomScene.title)")

            // Log performers in the new scene for debugging
            if let performers = randomScene.performers, !performers.isEmpty {
              // Always store just the first performer name for consistency
              let firstPerformerName = performers[0].name
              print("🎭 New scene contains primary performer: \(firstPerformerName)")

              // Enhanced gender detection logic matching getCurrentPerformerIDs
              let femalePerformers = performers.filter { performer in
                // If gender is nil, check the name for clues
                guard let gender = performer.gender?.lowercased() else {
                  // For nil gender, look for clues in the name that might suggest male
                  let name = performer.name.lowercased()
                  let commonMaleIndicators = [
                    "mr.", "mr ", "male", "boy", "man", "guy", "dude", "his", "him",
                  ]

                  // If any male indicators are in the name, assume male
                  for indicator in commonMaleIndicators {
                    if name.contains(indicator) {
                      print(
                        "🎭 DEBUG: Filtering out '\(performer.name)' because name contains male indicator: \(indicator)"
                      )
                      return false
                    }
                  }

                  // Otherwise, assume female
                  print(
                    "🎭 DEBUG: Treating '\(performer.name)' as female because gender is nil and name has no male indicators"
                  )
                  return true
                }

                // Check for explicitly female indicators first (highest priority)
                if gender == "female" || gender == "f" || gender.contains("female")
                  || gender.contains("woman") || gender.contains("girl") || gender.contains("f/")
                {
                  print(
                    "🎭 DEBUG: Including '\(performer.name)' because gender is explicitly female: \(gender)"
                  )
                  return true
                }

                // Then check for explicitly male indicators
                let isMale =
                  gender == "male" || gender == "m" || gender == "man" || gender == "men"
                  || gender == "boy" || gender.contains("m/")
                  || (gender.contains("male") && !gender.contains("female")
                    && !gender.contains("shemale"))

                if isMale {
                  print(
                    "🎭 DEBUG: Filtering out '\(performer.name)' because gender is male: \(gender)")
                  return false
                } else {
                  print("🎭 DEBUG: Including '\(performer.name)' as female with gender: \(gender)")
                  return true
                }
              }

              if !femalePerformers.isEmpty {
                print("🎭 Scene contains \(femalePerformers.count) female performer(s)")
              } else {
                print("🎭 No female performers in this scene")
              }
            } else {
              print("🎭 New scene has no performers")
            }

            showControls = false
          }

          // Since we're in pure random, default to position 0
          let finalTargetPosition: Double = 0

          // Verify that we actually have a playable video
          // This checks for critical errors about 10 seconds after setup
          Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10s delay

            // If the player is nil, item is nil, or duration is zero, something went wrong
            let hasPlayer = playerManager.player != nil
            let hasPlayerItem = playerManager.player?.currentItem != nil
            let hasDuration = playerManager.duration > 0
            let isPlaying = playerManager.player?.timeControlStatus == .playing
            let currentPos = playerManager.currentTime
            let isCurrentPosValid = !currentPos.isNaN && currentPos > 0

            print(
              "🔍 Final sanity check - Player: \(hasPlayer), Item: \(hasPlayerItem), Duration: \(hasDuration), Playing: \(isPlaying), Pos: \(currentPos)"
            )

            // If critical checks fail, show an error and retry buttons
            if !hasPlayer || !hasPlayerItem || !hasDuration || !isPlaying {
              print("⚠️ Critical playback failure detected in sanity check")
              await MainActor.run {
                showFeedback("Video failed - try another")
                showControls = true
              }
            } else if !isCurrentPosValid && finalTargetPosition > 0 {
              // One last attempt to fix position if it's wrong
              print("🔄 Making final position adjustment to \(formatTime(finalTargetPosition))")
              playerManager.seek(to: finalTargetPosition)
              playerManager.player?.play()
            }
          }
        }
      } catch {
        print("Error fetching pure random video: \(error)")
        // If there's an error, show controls so user can try again
        await MainActor.run {
          showControls = true
        }
      }
    }
  }

  // Helper method to check if a scene has a VR tag
  private func hasVRTag(_ scene: StashScene) -> Bool {
    guard let tags = scene.tags else { return false }

    // Check for VR tag or tag containing "vr", "180", "360"
    return tags.contains { tag in
      let name = tag.name.lowercased()
      return name == "vr" || name.contains("vr ") || name.contains(" vr") || name.contains("180")
        || name.contains("360")
    }
  }

  // Helper method to print debug info about a scene including file oshash
  private func printSceneDebugInfo(_ scene: StashScene) {
    Task {
      print("🔬 SCENE DEBUG INFO")
      print("🔬 Scene ID: \(scene.id)")
      print("🔬 Scene title: \(scene.title)")

      // Try to get oshash from API
      if let fileInfo = await getFileInfo(forSceneID: scene.id) {
        print("🔬 File info found:")
        for (key, value) in fileInfo {
          print("🔬   \(key): \(value)")
        }

        if let oshash = fileInfo["oshash"] as? String {
          print("🔬 OSHASH: \(oshash)")
          print("🔬 Expected VTT path: /Users/mediaserver/.stash/generated/vtt/\(oshash)_thumbs.vtt")
          print(
            "🔬 Expected sprite path: /Users/mediaserver/.stash/generated/vtt/\(oshash)_sprite.jpg")
        }
      } else {
        print("🔬 Could not get file info")
      }

      // Print file info from the scene object
      if let files = scene.files, !files.isEmpty {
        print("🔬 Scene has \(files.count) file(s):")
        for (index, file) in files.enumerated() {
          print("🔬 File \(index + 1):")
          print("🔬   Size: \(file.formattedSize)")
          print("🔬   Duration: \(file.duration ?? 0)")
          print("🔬   Codec: \(file.video_codec ?? "unknown")")
          print("🔬   Resolution: \(file.width ?? 0)x\(file.height ?? 0)")
        }
      } else {
        print("🔬 No files in scene object")
      }

      print("🔬 END DEBUG INFO")
    }
  }

  // Random video at a random position
  private func playRandomVideo() {
    // Store the current HLS mode
    let wasUsingHLS = playerManager.useHLS

    // Stop any existing preview audio and clean up current player
    GlobalVideoManager.shared.muteAll()
    playerManager.cleanup()

    Task {
      // Show loading indicator instead of controls
      await MainActor.run {
        playerManager.isLoading = true
      }

      let api = StashAPI()
      // Fetch a random scene using the API's random sort
      do {
        try await api.fetchScenes(page: 1, sort: "random")

        // First filter out any scenes with VR tags
        let nonVRScenes = api.scenes.filter { !hasVRTag($0) }

        print(
          "🔍 Found \(api.scenes.count) random scenes, \(nonVRScenes.count) remain after filtering out VR content"
        )

        // Make sure the scene has at least one female performer
        // First check for any scenes with female performers
        let scenesWithFemalePerformers = nonVRScenes.filter { scene in
          guard let performers = scene.performers, !performers.isEmpty else {
            return false
          }

          // Enhanced check for female performers
          return performers.contains { performer in
            // If gender is nil, check the name for clues
            guard let gender = performer.gender?.lowercased() else {
              // For nil gender, look for clues in the name that might suggest male
              let name = performer.name.lowercased()
              let commonMaleIndicators = [
                "mr.", "mr ", "male", "boy", "man", "guy", "dude", "his", "him",
              ]

              // If any male indicators are in the name, assume male
              for indicator in commonMaleIndicators {
                if name.contains(indicator) {
                  return false
                }
              }

              // Otherwise, assume female
              return true
            }

            // Check for explicitly female indicators first (highest priority)
            if gender == "female" || gender == "f" || gender.contains("female")
              || gender.contains("woman") || gender.contains("girl") || gender.contains("f/")
            {
              return true
            }

            // Then check for explicitly male indicators
            let isMale =
              gender == "male" || gender == "m" || gender == "man" || gender == "men"
              || gender == "boy" || gender.contains("m/")
              || (gender.contains("male") && !gender.contains("female")
                && !gender.contains("shemale"))

            return !isMale
          }
        }

        // Get a female performer scene if available, otherwise fall back to any scene
        let randomScene: StashScene?
        if !scenesWithFemalePerformers.isEmpty {
          randomScene = scenesWithFemalePerformers.first
          print(
            "🎬 Random video with female performer selected: \(randomScene?.title ?? "") - ID: \(randomScene?.id ?? "")"
          )
        } else {
          randomScene = nonVRScenes.first
          print(
            "🎬 No scenes with female performers found, using fallback non-VR scene: \(randomScene?.title ?? "") - ID: \(randomScene?.id ?? "")"
          )
        }

        // Continue if we have a valid scene
        if let randomScene = randomScene {
          print("🎬 Random video selected: \(randomScene.title) - ID: \(randomScene.id)")

          // Calculate a random start time
          var randomStartTime: Double = 0

          // Get the video duration
          let videoDuration = randomScene.files?.first?.duration ?? 0
          print("🔍 videoDuration: \(videoDuration)")

          if videoDuration > 0 {
            // Calculate minimum of 5 minutes or video duration
            let minimumStartTime = min(5 * 60, videoDuration * 0.25)
            print("🔍 minimumStartTime: \(minimumStartTime)")

            // Calculate maximum startTime (about 75% into the video to ensure enough content remains)
            let maximumStartTime = videoDuration * 0.75
            print("🔍 maximumStartTime: \(maximumStartTime)")

            // Ensure we have enough playback time
            if maximumStartTime > minimumStartTime {
              // Generate random time between minimum and maximum
              randomStartTime = Double.random(in: minimumStartTime...maximumStartTime)
            } else {
              // Fall back to 5-minute mark or beginning if video is too short
              randomStartTime = videoDuration > 300 ? 300 : 0
            }
          }

          // Use a two-step approach to ensure position is maintained when switching modes

          // Step 1: Calculate the position we want to end up at
          let targetPosition = randomStartTime
          print("🎬 Target playback position: \(formatTime(targetPosition))")

          // Get performer information for the new scene - only first performer
          var performerName = "Unknown performer"
          if let performers = randomScene.performers, !performers.isEmpty {
            // Just take the first performer's name
            performerName = performers[0].name
            print(
              "🎭 New scene features \(performers.count) performers, showing only first: \(performerName)"
            )

            // Log all performers for debugging
            for (index, performer) in performers.enumerated() {
              let gender = performer.gender ?? "nil"
              print(
                "🎭 DEBUG: Performer \(index + 1)/\(performers.count): \(performer.name) (gender: \(gender))"
              )
            }
          } else {
            print("🎭 New scene has no listed performers")
          }

          // Show feedback to user about random position and performer
          if targetPosition > 0 {
            showFeedback("\(performerName) - \(formatTime(targetPosition))")
          } else {
            showFeedback(performerName)
          }

          // CRITICAL: Store the position for fallback recovery with enhanced method
          // This will persist even if the player fails with direct mode and retries with HLS
          // The enhanced implementation stores positions in multiple locations for redundancy
          playerManager.preservePositionForFallback(scene: randomScene, position: targetPosition)

          // Log so we can track what's happening
          print(
            "🎬 Preparing to seek to position \(formatTime(targetPosition)) with fallback protection"
          )

          // Get the current fallback attempt count for diagnostics
          let attemptCount = playerManager.incrementFallbackAttempt(for: randomScene.id)

          // Ensure we have the correct HLS mode
          if wasUsingHLS && !playerManager.useHLS {
            print("🎬 Explicitly setting HLS mode before player setup")
            playerManager.useHLS = true
          }

          // Set up multiple safeguards to maintain position
          await MainActor.run {
            appModel.videoStartTime = targetPosition
            // Enable fallback mode to prevent position reset
            playerManager.isPerformingFallback = true
          }

          // MOST IMPORTANT: Use the startTime parameter directly
          print("🎬 Setting up player with explicit startTime: \(targetPosition)")
          await playerManager.setupPlayer(for: randomScene, startTime: targetPosition)

          // Add backup position maintenance
          if targetPosition > 0 {
            // Wait for player to fully initialize (longer delay for HLS)
            let delay = playerManager.useHLS ? 1_000_000_000 : 500_000_000  // 1s for HLS, 500ms for direct
            try? await Task.sleep(nanoseconds: UInt64(delay))

            // First verify if we're at the right position
            let currentPos = playerManager.currentTime
            print("🎬 Position check after setup: current=\(currentPos), target=\(targetPosition)")

            // Only seek if we're not close to the target
            if abs(currentPos - targetPosition) > 5.0 {
              print("⚠️ Position mismatch detected! Forcing seek to target position")
              playerManager.seek(to: targetPosition)

              // For HLS, add extra seeks with delays to ensure position sticks
              if playerManager.useHLS {
                // The extreme position verification has been removed to simplify the code.
              }
            } else {
              print("✅ Position maintained correctly during setup")
            }
          }

          // CRITICAL: Update the scene reference to the new scene
          // This ensures performer shuffle will use the correct performer
          await MainActor.run {
            self.scene = randomScene
            print("🎭 Updated scene reference to: \(randomScene.title)")

            // Log performers in the new scene for debugging
            if let performers = randomScene.performers, !performers.isEmpty {
              // Always store just the first performer name for consistency
              let firstPerformerName = performers[0].name
              print("🎭 New scene contains primary performer: \(firstPerformerName)")

              // Enhanced gender detection logic matching getCurrentPerformerIDs
              let femalePerformers = performers.filter { performer in
                // If gender is nil, check the name for clues
                guard let gender = performer.gender?.lowercased() else {
                  // For nil gender, look for clues in the name that might suggest male
                  let name = performer.name.lowercased()
                  let commonMaleIndicators = [
                    "mr.", "mr ", "male", "boy", "man", "guy", "dude", "his", "him",
                  ]

                  // If any male indicators are in the name, assume male
                  for indicator in commonMaleIndicators {
                    if name.contains(indicator) {
                      print(
                        "🎭 DEBUG: Filtering out '\(performer.name)' because name contains male indicator: \(indicator)"
                      )
                      return false
                    }
                  }

                  // Otherwise, assume female
                  print(
                    "🎭 DEBUG: Treating '\(performer.name)' as female because gender is nil and name has no male indicators"
                  )
                  return true
                }

                // Check for explicitly female indicators first (highest priority)
                if gender == "female" || gender == "f" || gender.contains("female")
                  || gender.contains("woman") || gender.contains("girl") || gender.contains("f/")
                {
                  print(
                    "🎭 DEBUG: Including '\(performer.name)' because gender is explicitly female: \(gender)"
                  )
                  return true
                }

                // Then check for explicitly male indicators
                let isMale =
                  gender == "male" || gender == "m" || gender == "man" || gender == "men"
                  || gender == "boy" || gender.contains("m/")
                  || (gender.contains("male") && !gender.contains("female")
                    && !gender.contains("shemale"))

                if isMale {
                  print(
                    "🎭 DEBUG: Filtering out '\(performer.name)' because gender is male: \(gender)")
                  return false
                } else {
                  print("🎭 DEBUG: Including '\(performer.name)' as female with gender: \(gender)")
                  return true
                }
              }

              if !femalePerformers.isEmpty {
                print("🎭 Scene contains \(femalePerformers.count) female performer(s)")
              } else {
                print("🎭 No female performers in this scene")
              }
            } else {
              print("🎭 New scene has no performers")
            }

            showControls = false
          }

          // Since we're in pure random, default to position 0
          let finalTargetPosition: Double = 0

          // Verify that we actually have a playable video
          // This checks for critical errors about 10 seconds after setup
          Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10s delay

            // If the player is nil, item is nil, or duration is zero, something went wrong
            let hasPlayer = playerManager.player != nil
            let hasPlayerItem = playerManager.player?.currentItem != nil
            let hasDuration = playerManager.duration > 0
            let isPlaying = playerManager.player?.timeControlStatus == .playing
            let currentPos = playerManager.currentTime
            let isCurrentPosValid = !currentPos.isNaN && currentPos > 0

            print(
              "🔍 Final sanity check - Player: \(hasPlayer), Item: \(hasPlayerItem), Duration: \(hasDuration), Playing: \(isPlaying), Pos: \(currentPos)"
            )

            // If critical checks fail, show an error and retry buttons
            if !hasPlayer || !hasPlayerItem || !hasDuration || !isPlaying {
              print("⚠️ Critical playback failure detected in sanity check")
              await MainActor.run {
                showFeedback("Video failed - try another")
                showControls = true
              }
            } else if !isCurrentPosValid && finalTargetPosition > 0 {
              // One last attempt to fix position if it's wrong
              print("🔄 Making final position adjustment to \(formatTime(finalTargetPosition))")
              playerManager.seek(to: finalTargetPosition)
              playerManager.player?.play()
            }
          }
        }
      } catch {
        print("Error fetching random video with random position: \(error)")
        // If there's an error, show controls so user can try again
        await MainActor.run {
          showControls = true
        }
      }
    }
  }

  // Helper function to get performer IDs from the current scene - filtered to female performers only
  private func getCurrentPerformerIDs() -> [String] {
    guard let performers = scene.performers else {
      return []
    }

    // Print raw gender data to debug
    for performer in performers {
      print("🎭 DEBUG: Performer '\(performer.name)' has gender: '\(performer.gender ?? "nil")'")
    }

    // IMPORTANT: In most Stash instances, gender is often not set or nil
    // We now use a more comprehensive approach to determining gender

    // ENHANCED LOGIC: Better female detection with multiple approaches
    let femalePerformers = performers.filter { performer in
      // If gender is nil, we need to check the name for clues
      guard let gender = performer.gender?.lowercased() else {
        // For nil gender, look for clues in the name that might suggest male
        let name = performer.name.lowercased()
        let commonMaleIndicators = [
          "mr.", "mr ", "male", "boy", "man", "guy", "dude", "his", "him",
        ]

        // If any male indicators are in the name, assume male
        for indicator in commonMaleIndicators {
          if name.contains(indicator) {
            print(
              "🎭 DEBUG: Filtering out '\(performer.name)' because name contains male indicator: \(indicator)"
            )
            return false
          }
        }

        // Otherwise, assume female
        print(
          "🎭 DEBUG: Treating '\(performer.name)' as female because gender is nil and name has no male indicators"
        )
        return true
      }

      // Check for explicitly female indicators first (highest priority)
      if gender == "female" || gender == "f" || gender.contains("female")
        || gender.contains("woman") || gender.contains("girl") || gender.contains("f/")
      {
        print(
          "🎭 DEBUG: Including '\(performer.name)' because gender is explicitly female: \(gender)")
        return true
      }

      // Then check for explicitly male indicators
      let isMale =
        gender == "male" || gender == "m" || gender == "man" || gender == "men" || gender == "boy"
        || gender.contains("m/")
        || (gender.contains("male") && !gender.contains("female") && !gender.contains("shemale"))

      // Log the decision for debugging
      if isMale {
        print("🎭 DEBUG: Filtering out '\(performer.name)' because gender is male: \(gender)")
        return false
      } else {
        print("🎭 DEBUG: Including '\(performer.name)' as female with gender: \(gender)")
        return true
      }
    }

    // Log the filtering results for debugging
    print("🎭 Found \(performers.count) total performers, \(femalePerformers.count) are female")

    if !femalePerformers.isEmpty {
      // Get the first female performer only
      let firstFemalePerformer = femalePerformers.first!
      print("🎭 Using first female performer: \(firstFemalePerformer.name)")

      // Return array with just the first female performer ID
      return [firstFemalePerformer.id]
    } else {
      // If no female performers, return empty array - DON'T use male performers
      print("🎭 No female performers found, returning empty array")
      return []
    }
  }

  // Helper function to format time in minutes:seconds format
  private func formatTime(_ time: Double) -> String {
    let totalSeconds = Int(time)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }

  // Fetch and play a random scene featuring the same performer as current scene
  private func playPerformerRandomVideo() {
    // Before cleaning up, store the current scene ID to check if we're returning to the same scene
    let currentSceneID = scene.id
    let currentPlaybackPosition = playerManager.currentTime

    // Store the current HLS mode before cleanup
    let wasUsingHLS = playerManager.useHLS

    // Stop any existing preview audio and clean up current player
    GlobalVideoManager.shared.muteAll()
    playerManager.cleanup()

    // Get performer IDs from current scene - filtered to female performers only
    // Will only return female performer IDs, nothing else
    let performerIDs = getCurrentPerformerIDs()

    print("🎭 DEBUG: Filtered performer IDs: \(performerIDs)")

    // Only show message and automatically fallback if there are truly no performers
    if performerIDs.isEmpty {
      // First clear loading state
      playerManager.isLoading = false

      // No performers at all in this scene
      showFeedback("No female performers - using random shuffle")
      print("🎭 Scene has no female performers at all")

      // Show controls so user can try other options
      showControls = true

      // Automatically fall back to random video after a short delay
      Task {
        try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds delay

        // Automatically call playRandomVideo as fallback
        print("🎭 No female performers found - falling back to random video")
        playRandomVideo()
      }

      return
    }

    print("🎭 Found female performer(s) in current scene, using ID: \(performerIDs[0])")

    // Get the selected performer ID
    let selectedPerformerID = performerIDs.randomElement()!

    // Find the performer's name
    var selectedPerformerName = "Unknown"
    if let performers = scene.performers,
      let selectedPerformer = performers.first(where: { $0.id == selectedPerformerID })
    {
      selectedPerformerName = selectedPerformer.name
      print("🎭 Selected performer: \(selectedPerformerName) (ID: \(selectedPerformerID))")
    }

    Task {
      // Show loading indicator
      await MainActor.run {
        playerManager.isLoading = true
        // Show temporary feedback with the performer's name
        showFeedback("Shuffling \(selectedPerformerName)")
      }

      let api = StashAPI()

      do {
        // Fetch scenes for the selected performer with random sort
        // We use a random seed in the API to ensure we get a truly random result
        let randomSeed = Int.random(in: 0...999999)
        try await api.fetchPerformerScenes(
          performerId: selectedPerformerID, sort: "random_\(randomSeed)")

        // First filter out any scenes with VR tags
        let nonVRScenes = api.scenes.filter { !hasVRTag($0) }

        print(
          "🔍 Found \(api.scenes.count) performer scenes, \(nonVRScenes.count) remain after filtering out VR content"
        )

        // Filter out the current scene to avoid replaying it
        let otherScenes = nonVRScenes.filter { $0.id != scene.id }

        if let randomScene = otherScenes.first ?? nonVRScenes.first {
          print(
            "🎬 Selected random scene for performer \(selectedPerformerID): \(randomScene.title)")

          // Determine if we're accidentally returning to the same scene
          let isSameScene = randomScene.id == currentSceneID

          // Calculate position: if it's the same scene, keep the current position
          // otherwise use a random position
          var startPosition: Double = 0

          if isSameScene {
            print(
              "🔄 Returning to the same scene, maintaining position at \(currentPlaybackPosition)")
            startPosition = currentPlaybackPosition
          } else {
            // Get the video duration
            let videoDuration = randomScene.files?.first?.duration ?? 0

            if videoDuration > 0 {
              // Calculate random position between 0% and 70% of the video
              startPosition = Double.random(in: 0...(videoDuration * 0.7))
            }
          }

          // Use a two-step approach to ensure position is maintained when switching modes

          // Step 1: Calculate the position we want to end up at
          let targetPosition = startPosition
          print("🎬 Target playback position: \(formatTime(targetPosition))")

          // Check if the video is actually playable
          guard let videoFiles = randomScene.files,
            !videoFiles.isEmpty,
            videoFiles.first?.duration ?? 0 > 0
          else {
            print("⚠️ Scene appears to have no valid video files: \(randomScene.id)")
            showFeedback("Video not available for \(selectedPerformerName)")
            playerManager.isLoading = false
            showControls = true
            return
          }

          // Create a feedback message with performer name, scene title, and position
          var feedbackMessage = "\(selectedPerformerName)"

          // Add position info if we're starting at a specific point
          if targetPosition > 0 {
            feedbackMessage += " • \(formatTime(targetPosition))"
          }

          // Show the enhanced feedback
          showFeedback(feedbackMessage)

          // CRITICAL: Store the position for fallback recovery with enhanced method
          // This will persist even if the player fails with direct mode and retries with HLS
          // The enhanced implementation stores positions in multiple locations for redundancy
          playerManager.preservePositionForFallback(scene: randomScene, position: targetPosition)

          // Log so we can track what's happening
          print(
            "🎬 Preparing to seek to position \(formatTime(targetPosition)) with fallback protection"
          )

          // Get the current fallback attempt count for diagnostics
          let attemptCount = playerManager.incrementFallbackAttempt(for: randomScene.id)

          // Ensure we have the correct HLS mode
          if wasUsingHLS && !playerManager.useHLS {
            print("🎬 Explicitly setting HLS mode before player setup")
            playerManager.useHLS = true
          }

          // Set up multiple safeguards to maintain position
          await MainActor.run {
            appModel.videoStartTime = targetPosition
            // Enable fallback mode to prevent position reset
            playerManager.isPerformingFallback = true
          }

          // MOST IMPORTANT: Use the startTime parameter directly
          print("🎬 Setting up player with explicit startTime: \(targetPosition)")
          await playerManager.setupPlayer(for: randomScene, startTime: targetPosition)

          // Add backup position maintenance
          if targetPosition > 0 {
            // Wait for player to fully initialize (longer delay for HLS)
            let delay = playerManager.useHLS ? 1_000_000_000 : 500_000_000  // 1s for HLS, 500ms for direct
            try? await Task.sleep(nanoseconds: UInt64(delay))

            // First verify if we're at the right position
            let currentPos = playerManager.currentTime
            print("🎬 Position check after setup: current=\(currentPos), target=\(targetPosition)")

            // Only seek if we're not close to the target
            if abs(currentPos - targetPosition) > 5.0 {
              print("⚠️ Position mismatch detected! Forcing seek to target position")
              playerManager.seek(to: targetPosition)

              // For HLS, add extra seeks with delays to ensure position sticks
              if playerManager.useHLS {
                // The extreme position verification has been removed to simplify the code.
              }
            } else {
              print("✅ Position maintained correctly during setup")
            }
          }

          // CRITICAL: Update the scene reference to the new scene
          // This ensures performer shuffle will use the correct performer
          await MainActor.run {
            self.scene = randomScene
            print("🎭 Updated scene reference to: \(randomScene.title)")

            // Log performers in the new scene for debugging
            if let performers = randomScene.performers, !performers.isEmpty {
              // Always store just the first performer name for consistency
              let firstPerformerName = performers[0].name
              print("🎭 New scene contains primary performer: \(firstPerformerName)")

              // Enhanced gender detection logic matching getCurrentPerformerIDs
              let femalePerformers = performers.filter { performer in
                // If gender is nil, check the name for clues
                guard let gender = performer.gender?.lowercased() else {
                  // For nil gender, look for clues in the name that might suggest male
                  let name = performer.name.lowercased()
                  let commonMaleIndicators = [
                    "mr.", "mr ", "male", "boy", "man", "guy", "dude", "his", "him",
                  ]

                  // If any male indicators are in the name, assume male
                  for indicator in commonMaleIndicators {
                    if name.contains(indicator) {
                      print(
                        "🎭 DEBUG: Filtering out '\(performer.name)' because name contains male indicator: \(indicator)"
                      )
                      return false
                    }
                  }

                  // Otherwise, assume female
                  print(
                    "🎭 DEBUG: Treating '\(performer.name)' as female because gender is nil and name has no male indicators"
                  )
                  return true
                }

                // Check for explicitly female indicators first (highest priority)
                if gender == "female" || gender == "f" || gender.contains("female")
                  || gender.contains("woman") || gender.contains("girl") || gender.contains("f/")
                {
                  print(
                    "🎭 DEBUG: Including '\(performer.name)' because gender is explicitly female: \(gender)"
                  )
                  return true
                }

                // Then check for explicitly male indicators
                let isMale =
                  gender == "male" || gender == "m" || gender == "man" || gender == "men"
                  || gender == "boy" || gender.contains("m/")
                  || (gender.contains("male") && !gender.contains("female")
                    && !gender.contains("shemale"))

                if isMale {
                  print(
                    "🎭 DEBUG: Filtering out '\(performer.name)' because gender is male: \(gender)")
                  return false
                } else {
                  print("🎭 DEBUG: Including '\(performer.name)' as female with gender: \(gender)")
                  return true
                }
              }

              if !femalePerformers.isEmpty {
                print("🎭 Scene contains \(femalePerformers.count) female performer(s)")
              } else {
                print("🎭 No female performers in this scene")
              }
            } else {
              print("🎭 New scene has no performers")
            }

            showControls = false
          }

          // Since we're in pure random, default to position 0
          let finalTargetPosition: Double = 0

          // Verify that we actually have a playable video
          // This checks for critical errors about 10 seconds after setup
          Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10s delay

            // If the player is nil, item is nil, or duration is zero, something went wrong
            let hasPlayer = playerManager.player != nil
            let hasPlayerItem = playerManager.player?.currentItem != nil
            let hasDuration = playerManager.duration > 0
            let isPlaying = playerManager.player?.timeControlStatus == .playing
            let currentPos = playerManager.currentTime
            let isCurrentPosValid = !currentPos.isNaN && currentPos > 0

            print(
              "🔍 Final sanity check - Player: \(hasPlayer), Item: \(hasPlayerItem), Duration: \(hasDuration), Playing: \(isPlaying), Pos: \(currentPos)"
            )

            // If critical checks fail, show an error and retry buttons
            if !hasPlayer || !hasPlayerItem || !hasDuration || !isPlaying {
              print("⚠️ Critical playback failure detected in sanity check")
              await MainActor.run {
                showFeedback("Video failed - try another")
                showControls = true
              }
            } else if !isCurrentPosValid && finalTargetPosition > 0 {
              // One last attempt to fix position if it's wrong
              print("🔄 Making final position adjustment to \(formatTime(finalTargetPosition))")
              playerManager.seek(to: finalTargetPosition)
              playerManager.player?.play()
            }
          }
        } else {
          print(
            "⚠️ No other scenes found for performer \(selectedPerformerID) (\(selectedPerformerName))"
          )
          await MainActor.run {
            showFeedback("No other scenes for \(selectedPerformerName)")
            showControls = true
            playerManager.isLoading = false
          }
        }
      } catch {
        print("❌ Error fetching scenes for performer \(selectedPerformerName): \(error)")
        await MainActor.run {
          showFeedback("Error loading \(selectedPerformerName) scenes")
          showControls = true
          playerManager.isLoading = false
        }
      }
    }
  }

  // Enhanced feedback helper with animation
  // Helper function to condense verbose feedback messages to shorter ones
  private func condenseFeedback(_ message: String) -> String {
    // Map verbose messages to shorter versions
    switch message.lowercased() {
    case let msg where msg.contains("switching to hls"):
      return "HLS Mode"
    case let msg where msg.contains("switching to direct"):
      return "Direct Mode"
    case let msg where msg.contains("successfully switched to hls"):
      return "HLS Mode Active"
    case let msg where msg.contains("successfully switched to direct"):
      return "Direct Mode Active"
    case let msg where msg.contains("auto-switching"):
      return "Auto HLS Mode"
    case let msg where msg.contains("hevc") && msg.contains("auto"):
      return "Auto HLS for HEVC"
    case let msg where msg.contains("black screen"):
      return "Try HLS Mode"
    default:
      // For performer names and other messages, keep them short
      if message.count > 25 {
        return String(message.prefix(22)) + "..."
      } else {
        return message
      }
    }
  }

  private func showFeedback(_ message: String) {
    // Use condensed, shorter feedback messages
    feedbackMessage = condenseFeedback(message)

    // Show the feedback with less dramatic animation
    withAnimation(.easeIn(duration: 0.2)) {
      showingFeedback = true
    }

    // Hide feedback after 1.0 second (reduced from 1.5 seconds)
    Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.2)) {  // Faster fade out
          showingFeedback = false
        }
      }
    }
  }

  // Helper to fetch file info including oshash from the Stash API
  private func getFileInfo(forSceneID id: String) async -> [String: Any]? {
    guard let url = VideoPlayerUtility.createURL(path: "/scene/\(id)/file", includeApiKey: true)
    else {
      print("❌ Failed to create URL for file info")
      return nil
    }

    // Create an authenticated request
    let request = VideoPlayerUtility.createAuthenticatedRequest(url: url)

    do {
      // Fetch the file info
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        print("🌐 File info HTTP response: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
          print("❌ Error: File info request failed (HTTP \(httpResponse.statusCode))")
          return nil
        }
      }

      // Try to parse the JSON response
      if let jsonString = String(data: data, encoding: .utf8),
        let jsonData = jsonString.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
        let files = json["files"] as? [[String: Any]],
        let firstFile = files.first
      {
        print("✅ Successfully retrieved file info with \(files.count) file(s)")
        return firstFile
      } else {
        print("❌ Failed to parse file info response")
        return nil
      }
    } catch {
      print("❌ Error fetching file info: \(error)")
      return nil
    }
  }
}

// MARK: - Loading and Error Views
private struct VideoLoadingView: View {
  var body: some View {
    VStack {
      ProgressView()
        .scaleEffect(2.0)
      Text("Loading video...")
        .foregroundStyle(.white)
        .padding(.top)
    }
  }
}

private struct VideoErrorView: View {
  let error: Error
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var playerManager: VideoPlayerManager
  @State private var isRetrying = false

  var body: some View {
    VStack(spacing: 16) {
      // Error title
      Text("Failed to load video")
        .foregroundStyle(.white)
        .font(.title2.bold())

      // Error explanation
      VStack(spacing: 8) {
        // Standard error message
        Text(getFriendlyErrorMessage(from: error))
          .foregroundStyle(.white)
          .font(.body)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        // Technical error details (collapsible)
        DisclosureGroup("Technical Details") {
          VStack(alignment: .leading, spacing: 4) {
            Text(error.localizedDescription)
              .foregroundStyle(.red)
              .font(.caption)

            if let nsError = error as NSError? {
              Text("Error domain: \(nsError.domain)")
                .foregroundStyle(.orange)
                .font(.caption2)
              Text("Error code: \(nsError.code)")
                .foregroundStyle(.orange)
                .font(.caption2)
              if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                Text("Underlying error: \(underlying.localizedDescription)")
                  .foregroundStyle(.orange)
                  .font(.caption2)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(Color.black.opacity(0.2))
          .cornerRadius(8)
        }
        .accentColor(.white)
        .padding(.horizontal)
      }

      // Action buttons
      VStack(spacing: 12) {
        // Toggle streaming mode and retry button
        Button(action: {
          // Toggle the streaming mode first
          let newMode = !playerManager.useHLS
          playerManager.useHLS = newMode
          playerManager.wasForceHLS = newMode  // Keep wasForceHLS in sync for UI

          // Check if this is an HEVC video and we're switching to Direct mode
          let isHEVCVideo =
            playerManager.currentScene?.files?.first?.video_codec?.lowercased() == "hevc"
          let isKnownHEVCVideo =
            playerManager.currentScene != nil
            && VideoPlayerManager.problematicCodecVideos.contains(playerManager.currentScene!.id)

          // Show warning for HEVC videos switching to Direct mode
          if (isHEVCVideo || isKnownHEVCVideo) && !newMode {
            // Post notification to warn about potential black screen with Direct mode
            NotificationCenter.default.post(
              name: NSNotification.Name("VideoPlayerFeedback"),
              object: nil,
              userInfo: ["message": "Warning: HEVC video may show black screen in Direct mode"]
            )
          }

          isRetrying = true
          // Restart the player with the new streaming settings
          Task {
            if let scene = playerManager.currentScene {
              // Store current position to continue playback from same point
              let currentPosition = playerManager.currentTime

              // Display feedback about mode switch
              let modeMessage = newMode ? "Switching to HLS mode..." : "Switching to Direct mode..."
              NotificationCenter.default.post(
                name: NSNotification.Name("VideoPlayerFeedback"),
                object: nil,
                userInfo: ["message": modeMessage]
              )

              // We're reusing the scene and just changing streaming format
              await playerManager.setupPlayer(for: scene, startTime: currentPosition)
            }
            isRetrying = false
          }
        }) {
          HStack {
            if isRetrying {
              ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
            } else {
              Image(systemName: "arrow.triangle.2.circlepath")
            }
            // Tell the user we're automatically trying the other streaming mode
            Text(
              isRetrying
                ? "Retrying..." : "Try \(playerManager.useHLS ? "Direct" : "HLS") Streaming Instead"
            )
          }
          .font(.headline)
          .foregroundColor(.white)
          .padding(.vertical, 12)
          .padding(.horizontal, 24)
          .background(Color.blue.opacity(0.7))
          .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(isRetrying)

        // Close button
        Button(action: {
          dismiss()
        }) {
          HStack {
            IconImage(name: "close", width: 32, height: 32, color: .white)
            Text("Close")
          }
          .font(.headline)
          .foregroundColor(.white)
          .padding(.vertical, 12)
          .padding(.horizontal, 24)
          .background(Color.red.opacity(0.7))
          .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
      }
      .padding(.top, 24)
    }
    .padding(24)
    .background(Color.black.opacity(0.7))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.5), radius: 12)
  }

  // Convert technical error codes to user-friendly messages
  private func getFriendlyErrorMessage(from error: Error) -> String {
    let nsError = error as NSError

    // AVFoundation errors
    if nsError.domain == AVFoundationErrorDomain {
      switch nsError.code {
      case -11828:
        return
          "Cannot open this video stream. Please try selecting another video. If this issue persists, try restarting the app or checking your Wi-Fi connection."
      case -11800:
        return "This video format is not supported. Please try another video."
      case -1100:
        return
          "There was a problem loading the video. The stream URL may be invalid or the server may be unavailable."
      case -11850:
        return
          "Network error while loading the video. Please check your internet connection and try again."
      case -11801:
        return "Corrupted media file. The video file appears to be damaged or incomplete."
      default:
        return "There was a problem playing this video. Please try again or select another video."
      }
    }

    // OS Status errors (underlying error often contains these)
    if nsError.domain == "NSOSStatusErrorDomain" {
      switch nsError.code {
      case -12847:
        return
          "Network connection issue. Your current Wi-Fi connection may be unstable. Try disabling and reenabling Wi-Fi, or moving closer to your router."
      case -12780:
        return
          "Network timeout. The connection to the video server timed out. Try again in a moment."
      case -12889:
        return
          "Your network connection was interrupted. Please check your Wi-Fi connection and try again."
      default:
        return
          "There was a network-related problem playing this video. Try selecting another video or checking your Wi-Fi connection."
      }
    }

    // Network errors
    if nsError.domain == NSURLErrorDomain {
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet:
        return "You're not connected to the internet. Please check your connection and try again."
      case NSURLErrorTimedOut:
        return "The connection timed out. The server might be busy or unreachable."
      case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
        return "Cannot connect to the server. Please check if the server is online and try again."
      case NSURLErrorNetworkConnectionLost:
        return "Network connection was lost. Your Wi-Fi connection may be unstable."
      case NSURLErrorSecureConnectionFailed:
        return
          "Secure connection failed. There might be an issue with the server's security certificate."
      default:
        return "There was a network problem loading this video. Please try again later."
      }
    }

    // Generic message for other errors
    return
      "There was a problem playing this video. Please try another video or check your connection."
  }
}

// MARK: - Helper Extension for UserDefaults
extension UserDefaults {
  // Helper method to check if a key exists in UserDefaults
  func contains(key: String) -> Bool {
    return object(forKey: key) != nil
  }
}

// MARK: - Thumbnail Overlay View
private struct ThumbnailOverlayView: View {
  let playerManager: VideoPlayerManager
  let isShowingThumbnail: Bool
  let thumbnailImage: UIImage?
  let thumbnailTime: Double
  let geometry: GeometryProxy

  // Calculate x position for thumbnail to follow scrubber position
  private func calculateThumbnailXPosition() -> CGFloat {
    // Calculate thumbnail position based on timeline percentage
    let ratio = thumbnailTime / playerManager.duration
    let position = geometry.size.width * CGFloat(ratio)

    // Constrain position to stay within screen bounds (prevent clipping at edges)
    let thumbnailWidth: CGFloat = 240 + 16  // Width + padding
    let minX = thumbnailWidth / 2 + 20  // Left margin
    let maxX = geometry.size.width - thumbnailWidth / 2 - 20  // Right margin

    return min(max(position, minX), maxX)
  }

  var body: some View {
    Group {
      if isShowingThumbnail, let image = thumbnailImage {
        VStack(spacing: 4) {
          // Time label
          Text(playerManager.formatTime(thumbnailTime))
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.8))
            .cornerRadius(6)

          // Thumbnail image with enhanced visuals
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 240, height: 135)
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 3)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .position(
          // Position horizontally based on time position in the video
          x: calculateThumbnailXPosition(),
          y: geometry.size.height / 2 - 80
        )
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: isShowingThumbnail)
  }
}

// MARK: - Video Controls View
private struct VideoControlsView: View {
  let playerManager: VideoPlayerManager
  let player: AVPlayer
  let showControls: Bool
  let geometry: GeometryProxy
  let onScrubbing: (DragGesture.Value, GeometryProxy) -> Void
  let onScrubEnd: (DragGesture.Value, GeometryProxy) -> Void
  let showFeedback: (String) -> Void
  let hideControls: () -> Void  // Added callback for hiding controls

  // Track current size for responsive layout
  @State private var currentSize: CGSize = .zero

  var body: some View {
    if showControls {
      VStack(spacing: 0) {
        Spacer()

        // Simple status icon showing current play/pause state
        Image(systemName: player.timeControlStatus == .playing ? "pause.circle" : "play.circle")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 80, height: 80)
          .foregroundColor(.white)
          .shadow(color: .black, radius: 3)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 40)

        // Time display
        HStack {
          Text(playerManager.formatTime(playerManager.currentTime))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black, radius: 2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(5)

          Spacer()

          Text(playerManager.formatTime(playerManager.duration))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black, radius: 2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(5)
        }
        .padding(.horizontal)
        .padding(.bottom, 6)

        // Custom progress bar - VisionOS optimized with larger touch targets and improved resize handling
        GeometryReader { scrubberGeometry in
          ZStack(alignment: .leading) {
            // Update current size whenever geometry changes
            Color.clear
              .onAppear {
                currentSize = scrubberGeometry.size
              }
              .onChange(of: scrubberGeometry.size) { _, newSize in
                currentSize = newSize
                print("📏 Scrubber geometry changed to \(newSize)")
              }

            // Extra large track with buttons for timeline manipulation
            HStack(spacing: 0) {
              // Create 10 equal tap targets across the progress bar
              ForEach(0..<10) { i in
                // Individual segment covering 10% of timeline
                Rectangle()
                  .fill(Color.clear)
                  .frame(height: 120)  // Extra tall for better touch targeting
                  .contentShape(Rectangle())
                  .onTapGesture {
                    // Calculate time based on segment position (0-9)
                    let segmentRatio = Double(i) / 10.0
                    let segmentEndRatio = Double(i + 1) / 10.0
                    let midRatio = (segmentRatio + segmentEndRatio) / 2
                    let time = playerManager.duration * midRatio

                    // Seek to this position immediately
                    print(
                      "🎬 Segment \(i + 1) tapped, seeking to: \(playerManager.formatTime(time))")
                    playerManager.seek(to: time)

                    // Show feedback for the seek operation
                    let formattedTime = playerManager.formatTime(time)
                    self.showFeedback("⏱ \(formattedTime)")
                  }
              }
            }

            // Visual elements - use VStack alignment .top to ensure proper stacking
            VStack(alignment: .leading, spacing: 0) {
              // Background track with glass material - visionOS 2.6
              ZStack(alignment: .leading) {
                // Glass background track
                RoundedRectangle(cornerRadius: 20)
                  .fill(.ultraThinMaterial)
                  .glassBackgroundEffect()
                  .frame(height: 40)
                  .overlay(
                    RoundedRectangle(cornerRadius: 20)
                      .stroke(.white.opacity(0.2), lineWidth: 1)
                  )

                // Progress fill with glass effect
                RoundedRectangle(cornerRadius: 20)
                  .fill(.thinMaterial)
                  .glassBackgroundEffect()
                  .overlay(
                    RoundedRectangle(cornerRadius: 20)
                      .fill(.white.opacity(0.6))
                  )
                  .frame(
                    width: calculateProgressWidth(
                      currentTime: playerManager.currentTime, duration: playerManager.duration,
                      totalWidth: scrubberGeometry.size.width), height: 40
                  )
                  .animation(.linear(duration: 0.5), value: playerManager.currentTime)
              }
            }

            // Extra-large thumb indicator with glass material - visionOS 2.6
            ZStack {
              // Glow effect with glass
              Circle()
                .fill(.ultraThinMaterial)
                .glassBackgroundEffect()
                .frame(width: 80, height: 80)
                .blur(radius: 8)

              // Thumb with glass and depth
              Circle()
                .fill(.regularMaterial)
                .glassBackgroundEffect()
                .overlay(
                  Circle()
                    .fill(.white.opacity(0.8))
                )
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .position(
              x: calculateProgressWidth(
                currentTime: playerManager.currentTime, duration: playerManager.duration,
                totalWidth: scrubberGeometry.size.width), y: 60
            )  // Fixed vertical position
            .hoverEffect(.lift)  // visionOS 2.6 lift effect for playhead
            .animation(.linear(duration: 0.5), value: playerManager.currentTime)  // Smooth animation for position changes
          }
          // Use preference key to track scrubber geometry
          .preference(key: ScrubberSizePreferenceKey.self, value: scrubberGeometry.size)
          // Add drag gesture for scrubbing with minimum distance of 0 for immediate response
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                // Calculate position in timeline with improved bounds checking
                let position = max(0, min(value.location.x, scrubberGeometry.size.width))
                // Calculate the ratio of scrubber position
                let ratio = position / max(1, scrubberGeometry.size.width)
                // Calculate time based on ratio
                let time = playerManager.duration * Double(ratio)

                // Update thumbnail preview
                onScrubbing(value, scrubberGeometry)

                // Live scrubbing - update position as you drag
                playerManager.currentTime = time

                // Show feedback while scrubbing
                self.showFeedback("⏱ \(playerManager.formatTime(time))")

                // Debug log
                print(
                  "🎬 Scrubbing at position: \(position)/\(scrubberGeometry.size.width), time: \(playerManager.formatTime(time))"
                )
              }
              .onEnded { value in
                // Calculate final position with improved bounds checking
                let position = max(0, min(value.location.x, scrubberGeometry.size.width))
                let ratio = position / max(1, scrubberGeometry.size.width)
                let time = playerManager.duration * Double(ratio)

                // Seek to final position
                playerManager.seek(to: time)
                onScrubEnd(value, scrubberGeometry)

                // Debug log
                print(
                  "🎬 Scrubbing ended at position: \(position)/\(scrubberGeometry.size.width), time: \(playerManager.formatTime(time))"
                )
              }
          )
        }
        .frame(height: 120)  // Increased height for larger touch target
        .padding(.horizontal)
        .padding(.bottom, 10)
      }
      .padding(.bottom, 40)
      .background(
        LinearGradient(
          gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
  }

  private func calculateProgressWidth(currentTime: Double, duration: Double, totalWidth: CGFloat)
    -> CGFloat
  {
    let safeDuration = max(duration, 1.0)
    let progress = currentTime / safeDuration
    let width = CGFloat(progress) * totalWidth
    return max(0, min(width, totalWidth))
  }
}

struct VideoControlsOverlay: View {
  let playerManager: VideoPlayerManager
  let player: AVPlayer
  let playPureRandomVideo: () -> Void  // White shuffle button - random start from beginning
  let playRandomVideo: () -> Void  // Purple shuffle button - random with time offset
  let playPerformerRandomVideo: () -> Void  // Green performer button - same performer
  let dismiss: () -> Void
  @State private var showStreamingOptions = false
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    HStack(spacing: 35) {  // Increased spacing between buttons from 20 to 35
      // Close button
      Button(action: dismiss) {
        IconImage(name: "close", width: 42, height: 42, color: .white)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area

      // Pure random video button (picks a random video but starts from beginning)
      Button(action: playPureRandomVideo) {
        IconImage(name: "shuffle", width: 42, height: 42, color: .white)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area

      // Random jump button (picks a random video and starts at a random position)
      Button(action: playRandomVideo) {
        // Keep the purple shuffle icon as requested
        Image(systemName: "shuffle.circle.fill")
          .font(.system(size: 42))  // Increased from 30
          .foregroundStyle(.purple)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area
      .help("Jump to random scene at random position")

      // Performer random button (shuffle only current performer's scenes)
      Button(action: playPerformerRandomVideo) {
        IconImage(name: "performershuffle", width: 42, height: 42, color: .green)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area
      .help("Find more scenes with this performer (females only)")

      // Sequential scene navigation (only show when multiple scenes available AND not in marker shuffle mode)
      if appModel.currentScenes.count > 1 && !appModel.isMarkerShuffleMode {
        // Previous scene button
        Button(action: { appModel.previousScene() }) {
          Image(systemName: "chevron.left.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.orange)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("Previous scene (random timestamp)")

        // Next scene button
        Button(action: { appModel.nextScene() }) {
          Image(systemName: "chevron.right.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.orange)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("Next scene (random timestamp)")
      }

      // Marker shuffle controls (only show when in marker shuffle mode)
      if appModel.isMarkerShuffleMode {
        // Previous marker button
        Button(action: { appModel.previousMarkerInShuffle() }) {
          Image(systemName: "backward.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.blue)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("Previous marker")

        // Next marker button
        Button(action: { appModel.nextMarkerInShuffle() }) {
          Image(systemName: "forward.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.blue)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("Next marker")

        // Exit shuffle button
        Button(action: { appModel.stopMarkerShuffle() }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 42))
            .foregroundStyle(.red)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("Exit marker shuffle")

        // Shuffle info display
        VStack(alignment: .leading, spacing: 2) {
          Text("Marker Shuffle")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.blue)
          Text(appModel.shuffleTagName)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.8))
          if !appModel.markerShuffleQueue.isEmpty {
            Text("History: \(appModel.markerShuffleQueue.count) markers")
              .font(.system(size: 10))
              .foregroundStyle(.white.opacity(0.6))
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          Capsule()
            .fill(Color.black.opacity(0.5))
            .shadow(color: .black.opacity(0.5), radius: 3)
        )
        .overlay(
          Capsule()
            .strokeBorder(Color.blue.opacity(0.7), lineWidth: 1.5)
        )
      }

      // Streaming mode toggle button that uses our dedicated toggleStreamingMode function
      Button(action: {
        // Use Task to run the async toggle function
        Task {
          await playerManager.toggleStreamingMode()
        }
      }) {
        HStack(spacing: 6) {  // Slightly increased spacing
          // Use custom icons from Icons folder
          Group {
            // Always use the globe icon, but change its color when in HLS mode (blue) vs Direct mode (green)
            IconImage(
              name: "globe", width: 42, height: 42,
              color: (playerManager.useHLS || playerManager.wasForceHLS) ? .blue : .green)
          }
          // Apply pulse effect when in fallback mode
          .symbolEffect(.pulse, options: .repeating, value: playerManager.isPerformingFallback)
          VStack(alignment: .leading, spacing: 2) {
            // Clearer mode indicator with visual distinction - blue for HLS, green for Direct
            Text((playerManager.useHLS || playerManager.wasForceHLS) ? "HLS Mode" : "Direct Mode")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle((playerManager.useHLS || playerManager.wasForceHLS) ? .blue : .green)

            // Explanatory text for current mode
            Text(
              (playerManager.useHLS || playerManager.wasForceHLS)
                ? "Smoother playback" : "Faster playback"
            )
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.8))

            // Check if current video is HEVC which might need HLS mode
            if let codec = playerManager.currentScene?.files?.first?.video_codec?.lowercased(),
              (codec.contains("hevc") || codec.contains("h265")) && !playerManager.useHLS
            {
              Text("HEVC video - try HLS if jittery")
                .font(.system(size: 10))
                .foregroundStyle(Color.red.opacity(0.9))
            }
          }
        }
        .padding(.horizontal, 16)  // Increased padding for better balance with larger icon
        .padding(.vertical, 12)  // Increased padding for better balance with larger icon
        .background(
          Capsule()
            .fill(Color.black.opacity(0.5))
            .shadow(color: .black.opacity(0.5), radius: 3)
        )
        .overlay(
          Capsule()
            .strokeBorder(
              (playerManager.useHLS || playerManager.wasForceHLS)
                ? Color.blue.opacity(0.7) : Color.green.opacity(0.7),
              lineWidth: 1.5
            )
        )
        .foregroundStyle(.white)
      }
      .buttonStyle(.plain).popover(isPresented: $showStreamingOptions) {
        VStack(spacing: 16) {
          Text("Streaming Mode")
            .font(.headline)

          // Local state to hold the selection
          let isHLS = Binding<Bool>(
            get: { playerManager.useHLS },
            set: {
              let currentPos = playerManager.currentTime
              playerManager.useHLS = $0
              // Make sure wasForceHLS stays in sync for UI consistency
              playerManager.wasForceHLS = $0
              print("🔄 Manual streaming mode switch to: \($0 ? "HLS" : "Direct")")

              // Note: Seeking state will be reset during cleanup

              // Reset fallback counters
              playerManager.directPlaybackRetryCount = 0
              playerManager.consecutiveStallCount = 0
              playerManager.isPerformingFallback = false

              // Force immediate application of the setting
              UserDefaults.standard.synchronize()

              // Auto-restart with new mode
              if let scene = playerManager.currentScene {
                playerManager.preservePositionForFallback(scene: scene, position: currentPos)
                Task {
                  await playerManager.setupPlayer(for: scene, startTime: currentPos)
                }
              }
            }
          )

          // Auto-fallback toggle
          let autoFallback = Binding<Bool>(
            get: { playerManager.autoFallbackEnabled },
            set: { playerManager.autoFallbackEnabled = $0 }
          )

          // Show more descriptive streaming mode options
          GroupBox {
            VStack(alignment: .leading, spacing: 12) {
              Picker("Streaming Mode", selection: isHLS) {
                Text("Direct (Faster)").tag(false)
                Text("HLS (Smoother)").tag(true)
              }
              .pickerStyle(.segmented)

              Divider()

              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  IconImage(
                    name: "globe", width: 16, height: 16,
                    color: isHLS.wrappedValue ? .secondary : .green)
                  Text("Direct Mode:")
                    .fontWeight(.medium)
                }
                Text("Faster playback, better for most videos")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  IconImage(
                    name: "globe", width: 16, height: 16,
                    color: isHLS.wrappedValue ? .blue : .secondary)
                  Text("HLS Mode:")
                    .fontWeight(.medium)
                }
                Text("Smoother playback, fixes jittery videos")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
          .padding(.horizontal, 6)

          // Auto-fallback toggle with better description
          Toggle(isOn: autoFallback) {
            VStack(alignment: .leading) {
              HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                  .imageScale(.small)
                Text("Auto-Fallback")
                  .font(.subheadline)
              }
              Text("Automatically switch modes if playback fails")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .padding(.horizontal)
          .disabled(playerManager.useHLS)  // Only applicable in direct mode

          // Add info about current video
          if let codec = playerManager.currentScene?.files?.first?.video_codec {
            Text("Current video codec: \(codec)")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
          }

          Button("Apply & Restart") {
            showStreamingOptions = false

            // Get current position before any changes
            let currentPos = playerManager.currentTime

            // Reset fallback counters when manually switching
            playerManager.directPlaybackRetryCount = 0
            playerManager.consecutiveStallCount = 0
            playerManager.isPerformingFallback = false

            // Note: Seeking state will be reset during cleanup and restart

            // Restart playback with current settings
            if let scene = playerManager.currentScene {
              // Store position explicitly for this scene
              playerManager.preservePositionForFallback(scene: scene, position: currentPos)

              Task {
                await playerManager.setupPlayer(for: scene, startTime: currentPos)
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 5)
        }
        .padding()
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
      }

      Spacer()
    }
    .padding(.horizontal, 30)  // Increased from default padding
    .padding(.top, 24)  // Increased from 16
    .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
  }
}

@MainActor
class VideoPlayerManager: NSObject, ObservableObject {
  // Static collection to track problematic codec videos (WMV/HEVC) for special handling
  static var problematicCodecVideos: Set<String> = []
  // Track consecutive failures per scene to skip problematic ones
  private static var sceneFailureCounts: [String: Int] = [:]

  // StashAPI instance for API calls
  let api = StashAPI()

  @Published var player: AVPlayer?
  @Published var isLoading = true {
    didSet {
      if isLoading {
        // Start black screen timeout when loading begins
        startBlackScreenTimeout()
      } else {
        // Cancel timeout when loading completes
        cancelBlackScreenTimeout()
        // Allow future black-screen skips once playback succeeds
        blackScreenFiredCount = 0
      }
    }
  }
  @Published var error: Error?
  @Published var currentTime: Double = 0
  @Published var duration: Double = 0
  @Published var errorMessage: String = ""
  @Published var thumbnailCache: [String: UIImage] = [:]
  @Published var vttEntries: [VideoPlayerUtility.VTTEntry] = []
  @Published var spriteSheetImage: UIImage?

  // Flag to track if initial seek has been performed for the current player setup
  private var hasPerformedInitialSeek = false

  // Black screen timeout mechanism
  private var blackScreenTimer: Timer?
  // Prevent runaway loops by limiting how often we auto-skip on black screen
  private var blackScreenFiredCount: Int = 0
  private var onBlackScreenTimeout: (() -> Void)?

  // HLS mode with UserDefaults persistence
  @Published var useHLS: Bool = false {
    didSet {
      // Save HLS preference when it changes
      UserDefaults.standard.set(useHLS, forKey: "player_use_hls_mode")
      print("💾 Saved HLS mode preference: \(useHLS)")

      // Update wasForceHLS when HLS mode changes - Log for debugging
      if useHLS {
        print("⚙️ Setting wasForceHLS=true because useHLS=true")
        wasForceHLS = true
      } else if !isPerformingFallback {
        // Only reset wasForceHLS when explicitly switching to Direct mode from UI
        // and NOT during fallback or initialization
        print("⚙️ Setting wasForceHLS=false because useHLS=false (not in fallback mode)")
        wasForceHLS = false
      } else {
        print("⚙️ Preserving wasForceHLS state during fallback operation")
      }
    }
  }

  // Tracks if HLS mode was forced by a fallback or user toggle
  @Published var wasForceHLS: Bool = false {
    didSet {
      // Save when this changes since it's critical for mode persistence
      UserDefaults.standard.set(wasForceHLS, forKey: "player_was_force_hls")
      print("💾 Saved wasForceHLS preference: \(wasForceHLS)")
    }
  }

  @Published var currentScene: StashScene?  // Store the current scene for retry operations

  // Auto-fallback properties
  @Published var autoFallbackEnabled: Bool {
    didSet {
      // Save auto-fallback preference when it changes
      UserDefaults.standard.set(autoFallbackEnabled, forKey: "player_auto_fallback_enabled")
      print("💾 Saved auto-fallback preference: \(autoFallbackEnabled)")
    }
  }

  var directPlaybackRetryCount: Int = 0
  private var maxRetryAttempts: Int = 5
  var lastPlaybackPosition: Double = 0
  var isPerformingFallback: Bool = false
  var needsExplicitPlayAfterSetup: Bool = false  // Flag to enforce playback after setup
  // Feature flag: disable advancement stall monitor to avoid false restarts
  var enableStallMonitor: Bool = false

  // Black screen timeout methods
  func setBlackScreenTimeoutCallback(_ callback: @escaping () -> Void) {
    onBlackScreenTimeout = callback
  }

  private func startBlackScreenTimeout() {
    // Cancel any existing timer
    cancelBlackScreenTimeout()

    // If we've already fired once during this loading session, don't schedule again
    if blackScreenFiredCount > 0 {
      print("⏱️ Black screen timeout already fired once — suppressing repeats")
      return
    }

    print("⏱️ Starting 5-second black screen timeout")
    blackScreenTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) {
      [weak self] _ in
      guard let self = self else { return }

      // Check if still loading after 5 seconds
      if self.isLoading {
        print("🚨 BLACK SCREEN TIMEOUT: Video still loading after 5 seconds, skipping to next video")

        // Trigger the timeout callback on main actor
        Task { @MainActor in
          self.blackScreenFiredCount += 1
          self.onBlackScreenTimeout?()
        }
      }
    }
  }

  private func cancelBlackScreenTimeout() {
    blackScreenTimer?.invalidate()
    blackScreenTimer = nil
  }

  // Initialize with direct mode for performance
  override init() {
    // First set default values before super.init()
    self.useHLS = false
    self.autoFallbackEnabled = false

    super.init()

    // CRITICAL - Load HLS preference from UserDefaults
    // This must be done AFTER super.init() to avoid property observer timing issues

    // First load wasForceHLS - this tracks if HLS mode was explicitly set by user
    let savedWasForceHLS = UserDefaults.standard.bool(forKey: "player_was_force_hls")

    // Next load the actual HLS mode setting
    if UserDefaults.standard.contains(key: "player_use_hls_mode") {
      let savedHLSMode = UserDefaults.standard.bool(forKey: "player_use_hls_mode")

      // Set useHLS first, then wasForceHLS to avoid duplicate saves
      useHLS = savedHLSMode
      wasForceHLS = savedWasForceHLS

      print(
        "🔄 LOADED HLS setting from preferences: \(savedHLSMode) (wasForceHLS: \(savedWasForceHLS))")
    } else {
      // Default to direct mode if not previously set
      useHLS = false
      wasForceHLS = false
      print("🔄 No HLS preference found, defaulting to Direct mode")
    }

    // Load auto-fallback preference
    if UserDefaults.standard.contains(key: "player_auto_fallback_enabled") {
      self.autoFallbackEnabled = UserDefaults.standard.bool(forKey: "player_auto_fallback_enabled")
    } else {
      // Default to enabled if not previously set
      self.autoFallbackEnabled = true
    }

    print(
      "🔄 VideoPlayerManager initialized with streaming mode: \(useHLS ? "HLS" : "Direct") and autoFallback=\(autoFallbackEnabled)"
    )
  }

  // Audio duplication tracking - new property to store the current audio session ID
  private var currentSessionId = UUID().uuidString

  private var timeObserver: Any?
  private var itemObservation: NSKeyValueObservation?
  private var seekTime: Double?
  private var isSeeking = false
  private var lastSeekTime: Date = Date()
  private let sessionId = UUID().uuidString
  private var statusObservation: AnyCancellable?
  private var bufferObservation: AnyCancellable?
  private var stallObservation: AnyCancellable?
  private var emptyBufferObservation: AnyCancellable?
  private var likelyToKeepUpObservation: AnyCancellable?
  private var currentItemObservation: AnyCancellable?
  private var assetImageGenerator: AVAssetImageGenerator?
  private var playerItemStatusObserver: NSKeyValueObservation?

  // New playback stall detector for auto-fallback
  private var playbackStallDetector: Task<Void, Never>?
  var consecutiveStallCount: Int = 0

  func setupPlayer(for scene: StashScene, startTime: Double? = nil) async {
    print("🎬 Setting up player for scene: \(scene.id)")

    // Get any previously preserved position for fallback recovery
    let preservedPosition = getPreservedPosition(for: scene.id)

    // Determine the effective start time with fallback handling
    var effectiveStartTime = startTime

    // Check if we have a preserved position for this specific scene
    if let position = preservedPosition {
      print(
        "🎯 FOUND PRESERVED POSITION: Using saved position \(formatTime(position)) for scene \(scene.id)"
      )
      effectiveStartTime = position
      // Clear the preserved position since we're using it now
      clearPreservedPosition(for: scene.id)
    }

    // Check if this is a problematic codec (WMV/HEVC) to use optimized HLS
    let isProblematicCodec =
      scene.files?.contains { file in
        let codec = file.video_codec?.lowercased() ?? ""
        return codec.contains("hevc") || codec.contains("h265") || codec.contains("h.265")
          || codec.contains("wmv") || codec.contains("msmpeg") || codec.contains("vc-1")
      } ?? false

    if isProblematicCodec {
      print("⚠️ Problematic codec detected (WMV/HEVC) - activating enhanced compatibility mode")

      // If this has a problematic codec and we're not already using HLS, force HLS mode with transcoding
      if !useHLS {
        print(
          "🔄 Following Stash's behavior: Automatically enabling HLS mode for problematic codec (WMV/HEVC)"
        )
        useHLS = true
        wasForceHLS = true  // Mark this as forced for tracking

        // Add to list of known problematic videos for future reference
        VideoPlayerManager.problematicCodecVideos.insert(scene.id)
      }
    }

    // Store the current playback position if we're performing a fallback
    if isPerformingFallback && player != nil {
      lastPlaybackPosition = currentTime
      print("📊 Preserved playback position at \(formatTime(lastPlaybackPosition)) for fallback")
    } else if effectiveStartTime != nil {
      // If this is an initial setup with startTime, preserve it for potential fallbacks
      lastPlaybackPosition = effectiveStartTime!
      print("📊 Using explicit start time: \(formatTime(lastPlaybackPosition))")
    } else {
      // Reset playback position for new videos
      lastPlaybackPosition = 0
    }

    // Important: When setting up a new video (different scene), preserve HLS mode if it was successful before
    // but reset other fallback flags
    let wasUsingHLS = useHLS

    // Ensure the next player setup (including fallbacks) performs the initial seek
    hasPerformedInitialSeek = false
    print("🔄 Reset initial-seek flag for new setup")

    // If this is a brand new scene (not a fallback of the same one), reset counters and mode
    if !isPerformingFallback || currentScene?.id != scene.id {
      directPlaybackRetryCount = 0
      consecutiveStallCount = 0
      isPerformingFallback = false
      print("🔄 Reset retry counters for new scene")

      // Only reset to direct mode for new videos if not manually set by user
      if useHLS && !wasForceHLS {
        print("🔄 Switching back to direct mode for new video to maximize performance")
        useHLS = false
      } else if wasForceHLS {
        print("🔒 Keeping HLS mode because user manually selected it")
      }
    }

    // Clean up any existing player first
    cleanup()

    // Set up notification observer for critical playback failures
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(
      self, name: NSNotification.Name("VideoPlaybackFailure"), object: nil)
    notificationCenter.addObserver(
      self,
      selector: #selector(handlePlaybackFailure),
      name: NSNotification.Name("VideoPlaybackFailure"),
      object: nil
    )

    // Use aggressive audio cleanup to prevent any echoing
    GlobalVideoManager.shared.forceStopAllAudio()

    await MainActor.run {
      isLoading = true
      error = nil
      errorMessage = ""
      thumbnailCache.removeAll()

      // Explicitly clear VTT entries and sprite image to prevent stale data
      spriteSheetImage = nil
      vttEntries.removeAll()

      assetImageGenerator = nil
      currentScene = scene  // Store the current scene for possible retry

      print("🧹 Reset all cached data for new video (scene ID: \(scene.id))")
    }

    // Create an API instance
    let api = StashAPI()

    // Prefer HLS on VPN/remote networks for reliability unless user manually forced direct
    if (api.networkMonitor.networkMode != .local) && !useHLS && !wasForceHLS {
      print(
        "🌐 Non-local network detected (\(api.networkMonitor.networkMode.description)) - preferring HLS"
      )
      useHLS = true
    }

    // Add a slight delay to ensure audio has been fully cleaned up
    do {
      try await Task.sleep(nanoseconds: 300_000_000)  // 300ms delay
      print("🎬 Audio cleanup pause complete, proceeding with player setup")
    } catch {
      print("⚠️ Sleep was interrupted: \(error)")
    }

    // Log which attempt this is if we're in a fallback cycle
    if isPerformingFallback {
      print(
        "🔁 Auto-fallback: Attempt #\(directPlaybackRetryCount + 1) of \(maxRetryAttempts) with \(self.useHLS ? "HLS" : "direct") streaming"
      )
    }

    // Use the object property for useHLS flag, so it can be toggled by UI
    var attemptCount = 0
    var setupSuccess = false

    // Debug log the current stream format
    print("🎬 Initial streaming format: \(self.useHLS ? "HLS" : "Direct")")

    while attemptCount < 2 && !setupSuccess {
      attemptCount += 1

      // Always use the effectiveStartTime we calculated at the beginning of this method
      // to ensure we respect preserved positions for fallback recovery
      let startTimeToUse = effectiveStartTime

      // Use VPN HLS fallback on second attempt if VPN is detected
      let request: URLRequest?
      if attemptCount == 2 && api.networkMonitor.networkMode == .vpn {
        print("🔄 Using VPN HLS fallback on second attempt")
        request = await api.getVPNHLSFallbackRequest(
          forSceneID: scene.id, startTime: startTimeToUse)
      } else {
        request = await api.getOptimizedStreamRequest(
          forSceneID: scene.id, startTime: startTimeToUse)
      }

      guard let request = request else {
        let errorMsg = "Failed to construct stream URL"
        print("❌ \(errorMsg)")

        // VPN-aware fallback logic
        if attemptCount == 1 {
          // For VPN connections, try HLS fallback instead of toggling
          if api.networkMonitor.networkMode == .vpn {
            print("🔄 VPN detected - trying HLS fallback for better compatibility")
            // Try VPN HLS fallback on next iteration
          } else {
            self.useHLS.toggle()
            print("🔄 Toggling streaming mode to \(self.useHLS ? "HLS" : "direct") automatically")
          }
        }
        continue
      }

      do {
        guard let url = request.url else {
          throw NSError(
            domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid stream URL"])
        }

        print("🎬 Using \(self.useHLS ? "HLS" : "direct") streaming URL: \(url.absoluteString)")

        // Generate a completely new session ID for each player setup
        // This helps avoid audio pipeline confusion
        currentSessionId = UUID().uuidString

        var headers = request.allHTTPHeaderFields ?? [:]
        headers["Accept"] = "*/*"
        // For HLS streams, make sure to set the right content-type expectation
        if self.useHLS {
          // Critical: Set proper MIME type for HLS/M3U8 streams
          headers["Accept"] = "application/vnd.apple.mpegurl, application/x-mpegURL, */*;q=0.8"
          headers["Content-Type"] = "application/vnd.apple.mpegurl"
        }
        headers["Accept-Language"] = "en-US,en;q=0.9"
        headers["Connection"] = "keep-alive"
        headers["X-Playback-Session-Id"] = currentSessionId

        // Print out URL details for debugging
        if self.useHLS {
          print("🎬 HLS DEBUG URL: \(url.absoluteString)")
          print("🎬 HLS DEBUG HEADERS: \(headers)")
        }

        // Try more resilient settings for problematic connections
        let assetOptions: [String: Any] = [
          "AVURLAssetHTTPHeaderFieldsKey": headers,
          "AVURLAssetAllowsExpensiveNetworkAccess": true,
          "AVURLAssetAllowsConstrainedNetworkAccess": true,
          "AVURLAssetUsesNSURLSessionKey": true,
          "AVURLAssetPreferPreciseDurationAndTimingKey": true,
          "AVURLAssetHTTPUserAgentKey":
            "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15",
          "AVURLAssetHTTPMaximumConnectionsPerHostKey": NSNumber(value: 5),
          "AVURLAssetHTTPMayUsePipeliningKey": NSNumber(value: true),
        ]

        let asset = AVURLAsset(url: url, options: assetOptions)

        // Create and configure the player item with more resilient settings
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 30
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        // For HLS streams, add special configuration
        if self.useHLS {
          // Increase maximum duration of buffer to avoid stalls with HLS
          playerItem.preferredForwardBufferDuration = 60

          // Make sure the stream is fresh by adding a timestamp to avoid caching issues
          print("🎬 HLS: Configured with enhanced buffer settings")

          // Check if this is an HEVC video that might need special handling
          let isHEVCVideo =
            scene.files?.contains { file in
              file.video_codec?.lowercased().contains("hevc") ?? false
                || file.video_codec?.lowercased().contains("h265") ?? false
                || file.video_codec?.lowercased().contains("h.265") ?? false
            } ?? false

          if isHEVCVideo {
            print("🎬 HEVC VIDEO DETECTED: Using optimized HLS playback settings")
            // Add more aggressive buffering for HEVC videos
            playerItem.preferredForwardBufferDuration = 90

            // Add to the list of known HEVC videos
            VideoPlayerManager.problematicCodecVideos.insert(scene.id)
          }

          // Request video tracks to be enabled by default (prevents black screen with audio)
          _ = playerItem.tracks.filter { track in
            if track.assetTrack?.mediaType.rawValue == "vide" {
              track.isEnabled = true
              print("🎬 HLS: Force-enabled video track")
            }
            return track.isEnabled
          }

          // Add black screen check scheduler - checks video rendering after delay
          let deadline = DispatchTime.now() + 2.0
          let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            NotificationCenter.default.post(
              name: NSNotification.Name("CheckVideoRenderingStatus"),
              object: nil
            )

            // Also post a user-facing message if we're in HLS mode
            if self.useHLS {
              NotificationCenter.default.post(
                name: NSNotification.Name("VideoPlayerFeedback"),
                object: nil,
                userInfo: ["message": "Playing in HLS mode"]
              )
            }
          }
          DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
        }

        // Better async timeout system so we don't get stuck
        var loadingTimedOut = false

        // Create timeout task
        let timeoutTask = Task {
          try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15 second timeout
          if !Task.isCancelled {
            print("⏱️ Asset loading timed out")
            loadingTimedOut = true
          }
        }

        // Try to pre-load asset
        do {
          try await asset.load(.tracks, .duration)
          // Cancel timeout if we succeeded
          timeoutTask.cancel()
        } catch {
          // Cancel timeout task
          timeoutTask.cancel()

          // If this fails, just continue with the player setup anyway
          print("⚠️ Asset preloading failed: \(error.localizedDescription)")

          // If the asset loading timed out or failed, throw an error to try alternate format
          if loadingTimedOut {
            throw NSError(
              domain: "VideoPlayerError", code: -1001,
              userInfo: [NSLocalizedDescriptionKey: "Loading timed out"])
          }
        }

        // Create player with explicit rate
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .pause

        // Check if this is an HEVC/H.265 video which might need special handling
        let isHEVCVideo = scene.files?.first?.video_codec?.lowercased() == "hevc"
        if isHEVCVideo {
          print("🎬 DETECTED HEVC/H.265 VIDEO - Using enhanced compatibility mode")

          // For HEVC, prefer HLS mode if not already using it
          if !self.useHLS {
            print("🎬 HEVC detected, suggesting HLS mode for better compatibility")
            // Don't force HLS, but remember this is an HEVC video for debugging
            // Add this scene to the list of known HEVC videos
            VideoPlayerManager.problematicCodecVideos.insert(scene.id)

            // Create timer to check for black screen issue specifically with HEVC
            let deadline = DispatchTime.now() + 3.0
            let workItem = DispatchWorkItem {
              // If we're playing an HEVC video and playback fails, suggest switching to HLS
              NotificationCenter.default.post(
                name: NSNotification.Name("CheckVideoRenderingStatus"),
                object: nil
              )
            }
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
          }
        }

        // Register with GlobalVideoManager
        GlobalVideoManager.shared.registerPlayer(player)

        // Observe player item status
        playerItemStatusObserver = playerItem.observe(\.status) { [weak self] item, _ in
          Task { @MainActor in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
              print("✅ Player item ready to play")
              self.isLoading = false
              let durationSeconds = item.duration.seconds
              if durationSeconds.isFinite && durationSeconds > 0 {
                self.duration = durationSeconds
                print("🎬 Video duration: \(self.formatTime(durationSeconds))")
              }

              // Check pixel aspect ratio for anamorphic videos
              Task {
                do {
                  let tracks = try await item.asset.loadTracks(withMediaType: .video)
                  if let videoTrack = tracks.first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    let formatDescriptions = try await videoTrack.load(.formatDescriptions)

                    if let formatDescription = formatDescriptions.first {
                      let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

                      // Try to get pixel aspect ratio from format description extensions
                      var pixelAspectRatioValue: CGFloat = 1.0
                      if let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] {
                        if let pixelAspectRatioDict = extensions["CVPixelAspectRatio"] as? [String: Any],
                           let hSpacing = pixelAspectRatioDict["HorizontalSpacing"] as? Int,
                           let vSpacing = pixelAspectRatioDict["VerticalSpacing"] as? Int,
                           vSpacing > 0 {
                          pixelAspectRatioValue = CGFloat(hSpacing) / CGFloat(vSpacing)
                        }
                      }

                      print("🎬 Video metadata:")
                      print("  - Storage size: \(dimensions.width)x\(dimensions.height)")
                      print("  - Natural size: \(naturalSize.width)x\(naturalSize.height)")
                      print("  - Pixel aspect ratio: \(pixelAspectRatioValue)")

                      if pixelAspectRatioValue != 1.0 {
                        let displayWidth = CGFloat(dimensions.width) * pixelAspectRatioValue
                        let displayRatio = displayWidth / CGFloat(dimensions.height)
                        print("  ⚠️ Non-square pixels detected!")
                        print("  - Display size should be: \(Int(displayWidth))x\(dimensions.height)")
                        print("  - Display aspect ratio: \(String(format: "%.3f", displayRatio)) (16:9 = 1.778)")
                      }
                    }
                  }
                } catch {
                  print("❌ Error checking video metadata: \(error)")
                }
              }

              // visionOS-specific fix: Start playback first, then seek
              // This prevents the player from entering a bad state during initialization
              print("▶️ Starting playback first (visionOS compatibility)")
              player.play()

              // If in HLS mode, use aggressive playback initiation
              if self.useHLS {
                player.playImmediately(atRate: 1.0)
              }

              // Now handle seeking after playback has started
              if let startTime = startTime {
                print("🎯 visionOS: Seeking to \(self.formatTime(startTime)) after playback started")

                // Wait a moment for playback to fully initialize
                Task {
                  // Give the player time to start playing (short like iPadOS)
                  try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 second

                  // Check if we've already performed initial seek (prevents looping in shuffle mode)
                  guard !self.hasPerformedInitialSeek else {
                    print("🎯 Skipping duplicate seek - already seeked to start position")
                    return
                  }

                  // Check if player is in a good state before seeking
                  guard player.currentItem?.status == .readyToPlay else {
                    print("⚠️ Player item not ready for seeking, skipping seek")
                    return
                  }

                  let time = CMTime(seconds: startTime, preferredTimescale: 600)
                  do {
                    print("🎯 visionOS: Performing delayed seek to \(self.formatTime(startTime))")
                    try await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                    print("✅ visionOS: Successfully seeked to \(self.formatTime(startTime))")

                    // Mark that we've performed the initial seek
                    await MainActor.run {
                      self.hasPerformedInitialSeek = true
                    }

                    // Resume playback after seeking
                    player.play()
                    print("▶️ visionOS: Resumed playback after seeking")
                  } catch {
                    print("⚠️ visionOS: Delayed seek failed: \(error)")
                  }
                }
              }

              // Start playback advancement monitor after player starts in direct mode
              if self.enableStallMonitor && !self.useHLS && self.autoFallbackEnabled {
                print("🔍 Starting playback advancement monitor for direct playback")
                self.startPlaybackAdvancementMonitor()
              }

            case .failed:
              print("❌ Player item failed: \(String(describing: item.error))")

              // Get detailed error information
              var errorDetails = "Unknown playback error"
              var errorCode = -1

              if let itemError = item.error as NSError? {
                errorDetails = itemError.localizedDescription
                errorCode = itemError.code

                // Log detailed error info
                print("❌ Error domain: \(itemError.domain)")
                print("❌ Error code: \(itemError.code)")
                if let underlyingError = itemError.userInfo[NSUnderlyingErrorKey] as? NSError {
                  print("❌ Underlying error: \(underlyingError)")
                }

                // IMMEDIATELY trigger fallback for critical AVFoundation errors
                // Specifically target the "Cannot Open" error which is common with direct playback
                if itemError.domain == AVFoundationErrorDomain
                  && (itemError.code == -11828 || itemError.code == -11800) && !self.useHLS
                  && self.autoFallbackEnabled
                {
                  print(
                    "🚨 Critical AVFoundation error detected: \(errorDetails) - initiating immediate fallback"
                  )

                  // Trigger the failure handler through notification
                  NotificationCenter.default.post(
                    name: NSNotification.Name("VideoPlaybackFailure"),
                    object: nil
                  )

                  // Don't set the error UI yet, since we'll attempt fallback
                  return
                }
              }

              if let errorLog = item.errorLog() {
                print("❌ Error log: \(errorLog)")
                for event in errorLog.events {
                  print("❌ Error event: \(event.errorComment ?? "no comment") at \(event.date)")
                }
              }

              // Set error info for UI display
              self.error = NSError(
                domain: "VideoPlayerError",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: errorDetails])
              self.errorMessage = errorDetails
              self.isLoading = false

            case .unknown:
              print("⚠️ Player item status unknown")

            @unknown default:
              break
            }
          }
        }

        // Add observer for playback stalls - these will help detect and recover from network issues
        // Store static pointers to ensure we're using the same context keys for KVO
        let playbackLikelyToKeepUpContext = UnsafeMutableRawPointer(bitPattern: 1)
        let playbackBufferEmptyContext = UnsafeMutableRawPointer(bitPattern: 2)

        playerItem.addObserver(
          self,
          forKeyPath: "playbackLikelyToKeepUp",
          options: [.new, .initial],
          context: playbackLikelyToKeepUpContext)

        playerItem.addObserver(
          self,
          forKeyPath: "playbackBufferEmpty",
          options: [.new, .initial],
          context: playbackBufferEmptyContext)

        // Set up time observation with very infrequent updates to prevent blinking
        timeObserver = player.addPeriodicTimeObserver(
          forInterval: CMTime(seconds: 1.0, preferredTimescale: 600),
          queue: DispatchQueue.global(qos: .utility)
        ) { [weak self] time in
          guard let self = self else { return }
          // Only update if we're not actively seeking
          guard !self.isSeeking else { return }

          // Also skip if we've seeked very recently (within 1.0 seconds) to prevent conflicts
          let timeSinceLastSeek = Date().timeIntervalSince(self.lastSeekTime)
          guard timeSinceLastSeek > 1.0 else { return }

          // Update UI on main thread
          Task { @MainActor in
            self.currentTime = time.seconds
          }
        }

        await MainActor.run {
          self.player = player
          print("✅ Player setup complete")
        }

        // Initialize image generator for thumbnails
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 320, height: 180)

        await MainActor.run {
          self.assetImageGenerator = generator
        }

        // Load VTT data for thumbnail scrubbing
        Task {
          // First try direct browsing of the mounted directory
          let mountedVttPath = "/Volumes/vtt"
          let fileManager = FileManager.default

          if fileManager.fileExists(atPath: mountedVttPath),
            let files = try? fileManager.contentsOfDirectory(atPath: mountedVttPath)
          {
            print("✅ Found \(files.count) files in mounted VTT directory")

            // Log some files for debugging
            let filesToLog = min(10, files.count)
            print("📋 First \(filesToLog) files in mounted directory:")
            for i in 0..<filesToLog {
              if i < files.count {
                print("  - \(files[i])")
              }
            }

            // Look for matching VTT and sprite files - try multiple VTT naming patterns
            // First look for *_thumbs.vtt files (standard format)
            for file in files where file.hasSuffix("_thumbs.vtt") || file.hasSuffix(".vtt") {
              // Get the base filename (oshash)
              let oshash: String
              if file.hasSuffix("_thumbs.vtt") {
                oshash = file.replacingOccurrences(of: "_thumbs.vtt", with: "")
              } else if file.hasSuffix(".vtt") {
                oshash = file.replacingOccurrences(of: ".vtt", with: "")
              } else {
                // Skip files we don't recognize
                continue
              }
              print("🔍 Found VTT file with oshash: \(oshash)")

              // Check if we also have the sprite file - try multiple sprite file naming patterns
              let possibleSpriteFilenames = [
                "\(oshash)_sprite.jpg",  // Standard format
                "\(oshash)_sprites.jpg",  // Plural variation
                "\(oshash)_sprite.png",  // PNG variation
                "\(oshash).jpg",  // Simple format
                "\(oshash).png",  // Simple PNG format
              ]

              // Find the first matching sprite file
              let matchingSprite = possibleSpriteFilenames.first { files.contains($0) }

              if let spriteFilename = matchingSprite {
                print("✅ Found matching sprite file: \(spriteFilename)")

                // Load VTT content from local file
                let vttPath = "\(mountedVttPath)/\(file)"
                if let content = try? String(contentsOfFile: vttPath) {
                  if let entries = VideoPlayerUtility.parseVTTContent(content) {
                    await MainActor.run {
                      self.vttEntries = entries
                      print("✅ Loaded \(entries.count) VTT entries from browsed directory")
                    }

                    // Load sprite image
                    let spritePath = "\(mountedVttPath)/\(spriteFilename)"
                    if let spriteImage = UIImage(contentsOfFile: spritePath) {
                      await MainActor.run {
                        self.spriteSheetImage = spriteImage
                        print(
                          "✅ Loaded sprite from browsed directory: \(spriteImage.size.width)x\(spriteImage.size.height)"
                        )
                      }
                    }
                    break
                  }
                }
              }
            }
          } else {
            print("❌ Mounted VTT directory not found or couldn't be read")
          }

          // Fall back to async version if directory browsing didn't work
          if self.vttEntries.isEmpty,
            let vttUrl = await VideoPlayerUtility.getVTTURLAsync(forSceneID: scene.id)
          {
            print("🔍 Attempting to load VTT from local or remote: \(vttUrl.absoluteString)")
            if let entries = await VideoPlayerUtility.parseVTT(from: vttUrl) {
              await MainActor.run {
                self.vttEntries = entries
                print("✅ Loaded \(entries.count) VTT entries from mounted location or server")
              }
            } else if let alternativeUrl = VideoPlayerUtility.getAlternativeVTTURL(
              forSceneID: scene.id),
              let entries = await VideoPlayerUtility.parseVTT(from: alternativeUrl)
            {
              await MainActor.run {
                self.vttEntries = entries
                print("✅ Loaded \(entries.count) VTT entries from alternative URL")
              }
            } else {
              // Try to get oshash from files
              print("🔍 Attempting to get oshash for VTT files")
              if let url = VideoPlayerUtility.createURL(
                path: "/scene/\(scene.id)/file", includeApiKey: true)
              {
                let request = VideoPlayerUtility.createAuthenticatedRequest(url: url)

                do {
                  let (data, _) = try await URLSession.shared.data(for: request)

                  // Try to parse the JSON response
                  if let jsonString = String(data: data, encoding: .utf8),
                    let jsonData = jsonString.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                    let files = json["files"] as? [[String: Any]],
                    let firstFile = files.first,
                    let oshash = firstFile["oshash"] as? String
                  {
                    print("✅ Found oshash: \(oshash) for scene \(scene.id)")

                    // Try paths with oshash - using proper direct path to server
                    let oshashPaths = [
                      // Full path to the VTT file
                      "/Users/mediaserver/.stash/generated/vtt/\(oshash)_thumbs.vtt"
                    ]

                    // Try to load VTT using oshash
                    for oshashPath in oshashPaths {
                      if let url = VideoPlayerUtility.createURL(
                        path: oshashPath, includeApiKey: true)
                      {
                        print("🔑 Trying VTT path with oshash: \(url.absoluteString)")
                        if let entries = await VideoPlayerUtility.parseVTT(from: url) {
                          await MainActor.run {
                            self.vttEntries = entries
                            print(
                              "✅ Successfully loaded \(entries.count) VTT entries using oshash: \(oshash)"
                            )
                          }
                          break
                        } else {
                          print("❌ Failed to load VTT from oshash path: \(oshashPath)")
                        }
                      }
                    }
                  } else {
                    print("❌ Failed to extract oshash from file info")
                  }
                } catch {
                  print("❌ Error fetching file info for oshash: \(error)")
                }
              }

              // If we still don't have VTT entries, provide helpful debugging info
              if self.vttEntries.isEmpty {
                print("ℹ️ No VTT entries found with standard methods or oshash approach.")
                print(
                  "🔍 VTT files should be in format: /Users/mediaserver/.stash/generated/vtt/{oshash}_thumbs.vtt"
                )
                print(
                  "🔍 Sprite files should be in format: /Users/mediaserver/.stash/generated/vtt/{oshash}_sprite.jpg"
                )
                print("🔍 Where {oshash} is the file hash like '0a01a1125b031e3e'")

                // Try to get additional debugging information if available
                if let files = scene.files, !files.isEmpty {
                  print("ℹ️ Scene has \(files.count) file(s) with the following properties:")
                  for (index, file) in files.enumerated() {
                    print(
                      "  - File \(index + 1): Size: \(file.formattedSize), Codec: \(file.video_codec ?? "unknown")"
                    )
                  }
                }
              }
            }
          }

          // Pre-load sprite sheet for faster thumbnail access
          // Try async version first to check local mounted files
          if let spriteUrl = await VideoPlayerUtility.getSpriteURLAsync(forSceneID: scene.id) {
            print(
              "🔍 Attempting to load sprite sheet from local or remote: \(spriteUrl.absoluteString)")

            // Handle both local file and remote URLs
            do {
              let image: UIImage?

              // Check if this is a local file URL
              if spriteUrl.isFileURL {
                print("🔍 Loading sprite from local file: \(spriteUrl.path)")
                image = UIImage(contentsOfFile: spriteUrl.path)
              } else {
                // Remote URL - load via network
                print("🔍 Loading sprite from remote URL")
                let (data, _) = try await URLSession.shared.data(from: spriteUrl)
                image = UIImage(data: data)
              }

              if let image = image {
                await MainActor.run {
                  self.spriteSheetImage = image
                  print("✅ Loaded sprite sheet: \(image.size.width)x\(image.size.height)")
                }
              } else {
                print("❌ Failed to decode sprite image")
              }
            } catch {
              print("❌ Error loading sprite sheet: \(error)")

              // Try alternative sprite URL
              if let alternativeUrl = VideoPlayerUtility.getAlternativeSpriteURL(
                forSceneID: scene.id)
              {
                print(
                  "🔍 Attempting to load sprite sheet from alternative URL: \(alternativeUrl.absoluteString)"
                )
                do {
                  let (data, _) = try await URLSession.shared.data(from: alternativeUrl)
                  if let image = UIImage(data: data) {
                    await MainActor.run {
                      self.spriteSheetImage = image
                      print("✅ Loaded sprite sheet from alternative URL")
                    }
                  }
                } catch {
                  print("❌ Error loading sprite sheet from alternative URL: \(error)")
                }
              }
            }
          }
        }

        // Mark setup as successful
        setupSuccess = true
      } catch {
        print(
          "❌ Error setting up player with \(self.useHLS ? "HLS" : "direct") streaming: \(error.localizedDescription)"
        )

        // Try alternate format on next iteration if we haven't yet
        if attemptCount < 2 {
          print("🔄 Trying alternative streaming method")
          self.useHLS.toggle()
        } else {
          // Implement auto-fallback behavior for direct streaming failures
          if autoFallbackEnabled && !self.useHLS {
            // Only count direct playback failures toward retry limit
            directPlaybackRetryCount += 1
            print(
              "🔁 Auto-fallback: Direct playback failed (attempt \(directPlaybackRetryCount) of \(maxRetryAttempts))"
            )

            // If we haven't exceeded max retries, try again
            if directPlaybackRetryCount < maxRetryAttempts {
              // Set flag to indicate we're in fallback mode
              isPerformingFallback = true

              // Use an async task to retry with a small delay
              Task {
                // Short delay before retry to prevent rapid cycling
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

                // Try again with same mode
                print("🔁 Auto-fallback: Retrying direct playback...")
                await setupPlayer(for: scene, startTime: lastPlaybackPosition)
              }
              return
            } else if directPlaybackRetryCount >= maxRetryAttempts {
              // Switch to HLS mode after exhausting direct streaming retries
              print(
                "🔄 Auto-fallback: Maximum direct playback retries (\(maxRetryAttempts)) reached, switching to HLS mode"
              )
              isPerformingFallback = true
              self.useHLS = true

              // Explicitly preserve the position to survive the mode switch
              preservePositionForFallback(scene: scene, position: lastPlaybackPosition)
              print(
                "🎯 Auto-fallback: Explicitly preserving position \(formatTime(lastPlaybackPosition)) for HLS fallback"
              )

              // Retry with HLS mode after a short delay
              Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
                print(
                  "🔄 Auto-fallback: Trying HLS mode at position \(formatTime(lastPlaybackPosition))"
                )
                await setupPlayer(for: scene, startTime: lastPlaybackPosition)
              }
              return
            }
          }

          // Create a more user-friendly error message for final failure
          let userFriendlyMessage: String
          let errorCode: Int

          if let nsError = error as NSError? {
            errorCode = nsError.code

            // Convert technical errors to user-friendly messages
            switch nsError.code {
            case -1:
              userFriendlyMessage = nsError.localizedDescription
            case -1009:
              userFriendlyMessage = "No internet connection. Please check your network."
            case -1001:
              userFriendlyMessage = "Request timed out. Your connection may be too slow."
            case -11828:
              userFriendlyMessage =
                "Cannot open video stream. Please try again or check your network connection."
            default:
              userFriendlyMessage = "Error playing video: \(nsError.localizedDescription)"
            }

            // Log detailed error info
            print("❌ Error domain: \(nsError.domain)")
            print("❌ Error code: \(nsError.code)")
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
              print("❌ Underlying error: \(underlyingError)")
            }
          } else {
            errorCode = -1
            userFriendlyMessage = "Error playing video: \(error.localizedDescription)"
          }

          // Reset fallback status if we're showing a final error
          isPerformingFallback = false

          await MainActor.run {
            self.error = NSError(
              domain: "VideoPlayerError", code: errorCode,
              userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
            self.errorMessage = userFriendlyMessage
            self.isLoading = false
          }
        }
      }
    }
  }

  // Start monitoring for playback advancement
  private func startPlaybackAdvancementMonitor() {
    // Cancel any existing monitor
    playbackStallDetector?.cancel()

    // Only monitor in direct mode
    if useHLS || !autoFallbackEnabled {
      return
    }

    // Create a new task that checks if playback is advancing
    playbackStallDetector = Task {
      var lastPosition: Double = 0
      var stuckCount = 0

      // Give initial time to start playing
      try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds initial delay

      while !Task.isCancelled {
        // Get current position
        let currentPos = currentTime

        // If player status is playing but time hasn't advanced in 5 seconds,
        // that's a stall that requires fallback
        if let player = player, player.timeControlStatus == .playing {
          let difference = abs(currentPos - lastPosition)

          // Check if time hasn't advanced more than 0.5 seconds in 5 seconds while playing
          if difference < 0.5 && currentPos > 0 {
            stuckCount += 1
            print(
              "⚠️ Playback not advancing: position=\(formatTime(currentPos)), previous=\(formatTime(lastPosition)), stuck count=\(stuckCount)/3"
            )

            if stuckCount >= 3 {
              print("🚨 Critical: Playback is stuck despite playing status")
              // Trigger playback failure notification
              NotificationCenter.default.post(
                name: NSNotification.Name("VideoPlaybackFailure"),
                object: nil
              )
              break
            }
          } else {
            // Reset counter if we're making progress
            if stuckCount > 0 {
              print("✅ Playback resumed advancing")
              stuckCount = 0
            }
          }
        }

        // Save current position for next comparison
        lastPosition = currentTime

        // Check every 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
      }
    }
  }

  // Handle KVO notifications for playback stalls
  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "playbackLikelyToKeepUp" {
      if let item = object as? AVPlayerItem, !item.isPlaybackLikelyToKeepUp {
        print("⚠️ Playback not likely to keep up - buffer issues")

        if !useHLS && autoFallbackEnabled {
          // If we're using direct playback, increment our stall counter
          consecutiveStallCount += 1
          print("📊 Stall counter: \(consecutiveStallCount)/3")

          // Check if we're experiencing excessive stalls
          // Only count in direct playback mode as HLS is our fallback
          if consecutiveStallCount >= 3 {
            print("⚠️ Multiple consecutive stalls detected in direct playback mode")

            // Cancel any existing stall detector
            playbackStallDetector?.cancel()

            // Create a new detector that will trigger a fallback if stalls continue
            playbackStallDetector = Task {
              // Give the player a brief chance to recover
              try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

              // If task wasn't cancelled, trigger fallback
              if !Task.isCancelled && consecutiveStallCount >= 3 {
                directPlaybackRetryCount += 1
                print(
                  "🔁 Auto-fallback: Excessive stalls detected, initiating fallback (attempt \(directPlaybackRetryCount) of \(maxRetryAttempts))"
                )

                if directPlaybackRetryCount >= maxRetryAttempts {
                  // Switch to HLS after max retries
                  print(
                    "🔄 Auto-fallback: Maximum direct playback retries (\(maxRetryAttempts)) reached due to stalls, switching to HLS mode"
                  )

                  // We have to preserve playback position
                  let currentPos = currentTime

                  // Switch to HLS mode
                  isPerformingFallback = true
                  useHLS = true
                  needsExplicitPlayAfterSetup = true  // Flag that force play is needed

                  if let scene = currentScene {
                    // Reset stall counter
                    consecutiveStallCount = 0

                    // Show a user notification that we're switching modes
                    NotificationCenter.default.post(
                      name: NSNotification.Name("VideoPlayerFeedback"),
                      object: nil,
                      userInfo: ["message": "Switching to HLS mode for better compatibility"]
                    )

                    // Explicitly preserve the position to survive the mode switch
                    preservePositionForFallback(scene: scene, position: currentPos)
                    print(
                      "🎯 Stall fallback: Explicitly preserving position \(formatTime(currentPos)) for HLS fallback"
                    )

                    // Start HLS playback at current position
                    Task {
                      await setupPlayer(for: scene, startTime: currentPos)

                      // Add forced play commands
                      if let player = self.player {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
                        print("▶️ Forced play after stall-triggered HLS mode switch")
                        player.play()
                        player.playImmediately(atRate: 1.0)

                        // Multiple play attempts to ensure it starts
                        Task {
                          for i in 1...5 {
                            try? await Task.sleep(nanoseconds: UInt64(i * 500_000_000))  // 0.5s intervals
                            if let currentPlayer = self.player,
                              currentPlayer.timeControlStatus != .playing
                            {
                              print("▶️ Additional play command #\(i) after stall fallback")
                              currentPlayer.play()
                            } else {
                              break
                            }
                          }

                          needsExplicitPlayAfterSetup = false
                        }
                      }
                    }
                  }
                } else {
                  // Reset the stall counter
                  consecutiveStallCount = 0

                  // Try to recover within direct playback mode by restarting player
                  if let player = self.player, player.status == .readyToPlay {
                    print("🔄 Attempting to recover from stalls without changing modes")
                    player.pause()
                    player.play()
                  }
                }
              }
            }
          }
        }

        // Original recovery logic - will attempt to recover naturally
        if let player = self.player, player.status == .readyToPlay {
          // Try to keep playing
          player.play()
        }
      } else {
        // Reset stall counter when playback is likely to keep up
        if consecutiveStallCount > 0 {
          print("✅ Playback recovered, resetting stall counter")
          consecutiveStallCount = 0

          // Cancel any pending stall detector
          playbackStallDetector?.cancel()
          playbackStallDetector = nil
        }
      }
    } else if keyPath == "playbackBufferEmpty" {
      if let item = object as? AVPlayerItem, item.isPlaybackBufferEmpty {
        print("⚠️ Playback buffer empty")

        if !useHLS && autoFallbackEnabled {
          // Only increment if we're not just starting playback
          // The buffer is normally empty when playback first starts
          if currentTime > 3.0 {
            // Increment buffer empty counter
            consecutiveStallCount += 1
            print("📊 Buffer empty counter: \(consecutiveStallCount)/3")

            // Make buffer empty detection less aggressive
            if consecutiveStallCount >= 3 {
              // Cancel any existing stall detector
              playbackStallDetector?.cancel()

              // Create a new detector with longer recovery time
              playbackStallDetector = Task {
                // Give more time to recover from buffer empty
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

                // Only trigger fallback if still having issues after the delay
                if !Task.isCancelled && consecutiveStallCount >= 3 && currentTime > 3.0 {
                  // Verify buffer is still empty before taking action
                  var isStillEmpty = false
                  if let currentItem = player?.currentItem {
                    isStillEmpty = currentItem.isPlaybackBufferEmpty
                  }

                  if isStillEmpty {
                    directPlaybackRetryCount += 1
                    print(
                      "🔁 Auto-fallback: Persistent empty buffer detected, initiating fallback (attempt \(directPlaybackRetryCount) of \(maxRetryAttempts))"
                    )

                    if directPlaybackRetryCount >= maxRetryAttempts {
                      // Switch to HLS after max retries
                      print(
                        "🔄 Auto-fallback: Maximum direct playback retries (\(maxRetryAttempts)) reached due to empty buffer, switching to HLS mode"
                      )

                      // Preserve playback position
                      let currentPos = currentTime

                      // Switch to HLS mode
                      isPerformingFallback = true
                      useHLS = true
                      needsExplicitPlayAfterSetup = true  // Flag for forced play

                      if let scene = currentScene {
                        // Reset stall counter
                        consecutiveStallCount = 0

                        // Show a user notification that we're switching modes
                        NotificationCenter.default.post(
                          name: NSNotification.Name("VideoPlayerFeedback"),
                          object: nil,
                          userInfo: ["message": "Switching to HLS mode for better compatibility"]
                        )

                        // Start HLS playback
                        Task {
                          await setupPlayer(for: scene, startTime: currentPos)

                          // Add forced play commands to ensure playback starts
                          if let player = self.player {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
                            print("▶️ Forced play after buffer-empty HLS mode switch")
                            player.play()
                            player.playImmediately(atRate: 1.0)

                            // Multiple play attempts
                            Task {
                              for i in 1...5 {
                                try? await Task.sleep(nanoseconds: UInt64(i * 500_000_000))  // 0.5s intervals
                                if let currentPlayer = self.player,
                                  currentPlayer.timeControlStatus != .playing
                                {
                                  print("▶️ Additional play command #\(i) after buffer fallback")
                                  currentPlayer.play()
                                } else {
                                  break
                                }
                              }

                              needsExplicitPlayAfterSetup = false
                            }
                          }
                        }
                      }
                    }
                  } else {
                    // Buffer is no longer empty, reset counter
                    print("✅ Buffer recovered, resetting counter")
                    consecutiveStallCount = 0
                  }
                }
              }
            }
          }
        }

        // If player is ready and buffer is empty, try to play
        if let player = self.player, player.status == .readyToPlay {
          player.play()
        }
      }
    } else {
      // Call super for any unhandled observations
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  // Handler for critical playback failures detected by the UIView
  @objc func handlePlaybackFailure(_ notification: Notification) {
    Task { @MainActor in
      print("🚨 Critical playback failure detected - initiating immediate fallback")

      // Increment per-scene failure count and consider skipping
      if let failingId = currentScene?.id {
        let c = (VideoPlayerManager.sceneFailureCounts[failingId] ?? 0) + 1
        VideoPlayerManager.sceneFailureCounts[failingId] = c
        print("📉 Scene \(failingId) failure count: \(c)")
        if c >= 2 {
          print("🚫 Scene \(failingId) failed twice — showing controls, not auto-shuffling")
          isLoading = false
          NotificationCenter.default.post(name: NSNotification.Name("ShowControls"), object: nil)
          // Keep counter so repeated errors won't thrash
          return
        }
      }

      // Apply to both direct and HLS playback for more robust fallback
      if autoFallbackEnabled {
        // Increment retry counter
        directPlaybackRetryCount += 1

        // If we're already in HLS mode and it's still failing, try alternative approach
        if useHLS && directPlaybackRetryCount >= 3 {
          // We've tried HLS and it's still failing - try one more time with WebM
          print("🔄 Critical failure: Trying alternative WebM format after HLS failures")

          // Auto-dismiss after too many failures
          if directPlaybackRetryCount >= 5 {
            print("🚨 Too many failures - showing emergency controls")

            // Show feedback and controls so user can exit
            NotificationCenter.default.post(
              name: NSNotification.Name("VideoPlayerFeedback"),
              object: nil,
              userInfo: ["message": "Video format not supported - try another"]
            )

            isLoading = false
            error = NSError(
              domain: "VideoPlayerError",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Video format not supported"])
            return
          }

          // Optional: try preview URL fallback (disabled by default due to instability)
          let enablePreviewFallback = false
          if enablePreviewFallback, let scene = currentScene {
            // Try to fetch scene details to check for preview format options
            let api = StashAPI()
            do {
              if let sceneDetails = try await api.fetchScene(byID: scene.id) {
                // Use a preview URL instead as fallback
                if let previewURL = sceneDetails.paths.preview,
                  let url = URL(string: previewURL)
                {
                  print("🔄 Trying preview URL as fallback: \(previewURL)")

                  // Clean up current player
                  cleanup()

                  // Show feedback to user
                  NotificationCenter.default.post(
                    name: NSNotification.Name("VideoPlayerFeedback"),
                    object: nil,
                    userInfo: ["message": "Trying preview format"]
                  )

                  // Create player for preview URL
                  let asset = AVURLAsset(url: url)
                  let playerItem = AVPlayerItem(asset: asset)
                  let player = AVPlayer(playerItem: playerItem)

                  // Set player and start playing
                  self.player = player
                  isLoading = false
                  player.play()

                  return
                }
              }
            } catch {
              print("⚠️ Failed to fetch scene details for fallback: \(error)")
            }
          }
        }

        // Main fallback logic - direct to HLS
        if !useHLS && directPlaybackRetryCount >= 2 {
          // We've tried direct playback enough, switch to HLS
          print(
            "🔄 Critical failure: Switching to HLS mode after \(directPlaybackRetryCount) direct playback attempts"
          )

          // Switch to HLS mode and remember position
          isPerformingFallback = true
          useHLS = true
          wasForceHLS = true  // CRITICAL: Explicitly set this flag for UI feedback
          needsExplicitPlayAfterSetup = true  // Flag that force play is needed

          if let scene = currentScene {
            // Use the position we saved or the current position (whichever is greater)
            let fallbackPosition = max(lastPlaybackPosition, currentTime)

            print("📊 Using fallback position: \(formatTime(fallbackPosition))")

            // Explicitly preserve the position to survive the mode switch
            preservePositionForFallback(scene: scene, position: fallbackPosition)
            print(
              "🎯 Critical failure: Explicitly preserving position \(formatTime(fallbackPosition)) for HLS fallback"
            )

            // Reset counters
            consecutiveStallCount = 0

            // Show a user notification that we're switching modes
            NotificationCenter.default.post(
              name: NSNotification.Name("VideoPlayerFeedback"),
              object: nil,
              userInfo: ["message": "Switching to HLS mode for better compatibility"]
            )

            // Restart with HLS
            isLoading = true  // Set loading state to show loading indicator

            // FIRST: Perform aggressive cleanup before switching formats
            cleanup()
            GlobalVideoManager.shared.forceStopAllAudio()

            // Reset audio session completely
            do {
              try AVAudioSession.sharedInstance().setActive(false)
              try AVAudioSession.sharedInstance().setCategory(.playback)
              try AVAudioSession.sharedInstance().setActive(true)
              print("✅ Audio session explicitly reset")
            } catch {
              print("⚠️ Failed to reset audio session: \(error)")
            }

            await setupPlayer(for: scene, startTime: fallbackPosition)

            // Add a forced play command after setup completes
            if let player = self.player {
              // Small delay to ensure player is ready
              try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
              print("▶️ Forced play after HLS mode switch")
              player.play()
              player.playImmediately(atRate: 1.0)

              // Schedule multiple play attempts to ensure it starts
              Task {
                for i in 1...5 {
                  try? await Task.sleep(nanoseconds: UInt64(i * 500_000_000))  // 0.5s intervals
                  if let currentPlayer = self.player, currentPlayer.timeControlStatus != .playing {
                    print("▶️ Additional play command #\(i) after HLS mode switch")
                    currentPlayer.play()

                    // Try forced rate setting
                    currentPlayer.playImmediately(atRate: 1.0)
                  } else {
                    print("✅ Playback is now playing, no more play commands needed")
                    break
                  }
                }

                // Check if playback started after all attempts
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
                if let currentPlayer = self.player,
                  currentPlayer.timeControlStatus != .playing
                    || (self.duration.isNaN || self.duration <= 0)
                {
                  print("⚠️ Playback still not working after multiple attempts - emergency fallback")

                  // Trigger the failure handler again to try alternative format
                  NotificationCenter.default.post(
                    name: NSNotification.Name("VideoPlaybackFailure"),
                    object: nil
                  )
                }

                // Reset the flag when the retry sequence is complete
                needsExplicitPlayAfterSetup = false
              }
            }
          }
        } else {
          // We still have attempts left, try direct playback again
          print(
            "🔁 Critical failure: Retry attempt \(directPlaybackRetryCount) of \(maxRetryAttempts) with \(self.useHLS ? "HLS" : "direct") mode"
          )

          // Mark as fallback but don't change mode yet
          isPerformingFallback = true

          if let scene = currentScene {
            // Use the position we saved or the current position (whichever is greater)
            let fallbackPosition = max(lastPlaybackPosition, currentTime)

            // Perform aggressive cleanup before retrying
            cleanup()
            GlobalVideoManager.shared.forceStopAllAudio()

            // Reset audio session completely
            do {
              try AVAudioSession.sharedInstance().setActive(false)
              try AVAudioSession.sharedInstance().setCategory(.playback)
              try AVAudioSession.sharedInstance().setActive(true)
              print("✅ Audio session explicitly reset")
            } catch {
              print("⚠️ Failed to reset audio session: \(error)")
            }

            // Retry current mode
            isLoading = true  // Set loading state to show loading indicator
            await setupPlayer(for: scene, startTime: fallbackPosition)

            // Add a forced play command after setup completes
            if let player = self.player {
              // Small delay to ensure player is ready
              try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
              print("▶️ Forced play after \(self.useHLS ? "HLS" : "direct") mode retry")
              player.play()
              player.playImmediately(atRate: 1.0)
            }
          }
        }
      }
    }
  }

  func cleanup() {
    print("🧹 Performing thorough player cleanup")

    // Cancel black screen timeout
    cancelBlackScreenTimeout()

    // Cancel any running stall detector task
    playbackStallDetector?.cancel()
    playbackStallDetector = nil

    // SafeKVO removal - just remove all possible observers for this object
    // This is a sledgehammer approach but works reliably
    NotificationCenter.default.removeObserver(self)
    print("🧹 Removed all KVO observers")

    // Handle player cleanup with extra safeguards
    if let player = player {
      // First mute and pause
      player.isMuted = true
      player.volume = 0
      player.pause()

      // Remove time observer
      if let timeObserver = timeObserver {
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
        print("🧹 Removed time observer")
      }

      // Replace player item with nil to fully stop playback and release resources
      player.replaceCurrentItem(with: nil)

      // Force a second replacement with nil for extra cleanup
      let deadline = DispatchTime.now() + 0.1
      let workItem = DispatchWorkItem { [weak player] in
        guard let player = player else { return }
        player.replaceCurrentItem(with: nil)
      }
      DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)

      // Unregister from global manager
      GlobalVideoManager.shared.unregisterPlayer(player)
      print("🧹 Unregistered player from global manager")
    }

    // Reset all observers
    playerItemStatusObserver?.invalidate()
    playerItemStatusObserver = nil

    itemObservation?.invalidate()
    itemObservation = nil

    statusObservation?.cancel()
    bufferObservation?.cancel()
    stallObservation?.cancel()
    emptyBufferObservation?.cancel()
    likelyToKeepUpObservation?.cancel()
    currentItemObservation?.cancel()

    // Release asset image generator
    assetImageGenerator = nil

    // Reset all state completely in one batch
    Task { @MainActor in
      player = nil
      currentTime = 0
      duration = 0
      error = nil
      errorMessage = ""

      // Reset seeking state variables
      isSeeking = false
      hasPerformedInitialSeek = false

      // Critical cache flush - this is super important for VTT issues
      print("🧹 CRITICAL: Clearing all caches and state data for proper reset")
      thumbnailCache.removeAll()
      vttEntries.removeAll()
      spriteSheetImage = nil
      currentScene = nil
    }

    // Reset audio session explicitly
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      print("✅ Audio session explicitly reset")
    } catch {
      print("⚠️ Audio session reset error: \(error)")
    }

    // Use the global manager cleanup as a fallback
    GlobalVideoManager.shared.stopAllPreviews()
    GlobalVideoManager.shared.forceStopAllAudio()
    print("✅ Used global manager for additional audio cleanup")

    print("✅ Player cleanup complete")
  }

  func seek(to time: Double) {
    guard let player = player else { return }

    print("🎬 Seeking to time: \(formatTime(time))")

    // Set seeking flag to prevent time observer conflicts
    isSeeking = true
    lastSeekTime = Date()

    // Use proper CMTime with high precision
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)

    // Use precise seeking for better results
    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
      guard let self = self, finished else {
        self?.isSeeking = false
        return
      }

      // Force update current time after seek and clear seeking flag
      Task { @MainActor in
        self.currentTime = time
        self.isSeeking = false

        // Ensure playback continues after seeking
        if player.timeControlStatus != .playing {
          player.play()
        }
      }
    }
  }

  // Dedicated function to handle HLS/Direct mode toggle
  func toggleStreamingMode() async {
    // Don't allow toggle while loading
    if isLoading {
      print("⚠️ TOGGLE IGNORED: Player is currently loading")
      return
    }

    // Capture current state
    let currentScene = self.currentScene
    let wasPlaying = player?.timeControlStatus == .playing
    let currentPosition = self.currentTime
    let newMode = !self.useHLS

    print(
      "🔄 🚨 TOGGLE: Forcing streaming mode to: \(newMode ? "HLS" : "Direct") at position \(formatTime(currentPosition))"
    )

    // Show immediate feedback to user
    NotificationCenter.default.post(
      name: NSNotification.Name("VideoPlayerFeedback"),
      object: nil,
      userInfo: ["message": "Switching to \(newMode ? "HLS" : "Direct") mode..."]
    )

    // Set flags for proper playback
    needsExplicitPlayAfterSetup = true

    // CRITICAL: Update all mode state variables in sync
    // Set wasForceHLS FIRST so that other code sees this as a manual user choice
    wasForceHLS = newMode
    useHLS = newMode

    print("🔒 MANUAL MODE CHANGE: User explicitly chose \(newMode ? "HLS" : "Direct") mode")

    // When forcing to HLS mode, also add to problematic codecs list for better handling
    if newMode, let scene = currentScene {
      // Add to problematic codecs list to ensure proper handling
      VideoPlayerManager.problematicCodecVideos.insert(scene.id)
      print("⚠️ Added \(scene.id) to problematic codecs list for better HLS handling")
    }

    // Force UserDefaults to save immediately
    UserDefaults.standard.set(newMode, forKey: "player_use_hls_mode")
    UserDefaults.standard.synchronize()

    guard let scene = currentScene else {
      print("⛔ TOGGLE FAILED: No current scene to reload")
      return
    }

    // Preserve position before cleanup
    preservePositionForFallback(scene: scene, position: currentPosition)

    // Clean up and show loading state
    isLoading = true
    cleanup()

    // Small delay to ensure cleanup completes
    try? await Task.sleep(nanoseconds: 400_000_000)  // 400ms

    // Double-check mode is still set correctly
    if useHLS != newMode {
      print("🔴 MODE LOST! Re-forcing mode")
      useHLS = newMode
      wasForceHLS = newMode
    }

    // Set up player with new mode
    await setupPlayer(for: scene, startTime: currentPosition)

    // Allow time for player to initialize
    try? await Task.sleep(nanoseconds: newMode ? 800_000_000 : 400_000_000)

    // Resume playback if needed
    if wasPlaying, let player = self.player {
      print("▶️ Resuming playback after mode switch")
      player.play()

      // Extra play attempts for reliability
      for i in 1...3 {
        try? await Task.sleep(nanoseconds: UInt64(i * 300_000_000))
        if let player = self.player, player.timeControlStatus != .playing {
          print("▶️ Additional play attempt #\(i)")
          player.play()
        } else {
          break
        }
      }
    }

    // Confirm successful switch
    NotificationCenter.default.post(
      name: NSNotification.Name("VideoPlayerFeedback"),
      object: nil,
      userInfo: ["message": "Successfully switched to \(newMode ? "HLS" : "Direct") mode"]
    )
  }

  func formatTime(_ time: Double) -> String {
    let totalSeconds = Int(time)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%02d:%02d", minutes, seconds)
    }
  }

  func generateThumbnail(at time: CMTime, completion: @escaping (UIImage?) -> Void) async {
    guard let player = player, let asset = player.currentItem?.asset else {
      completion(nil)
      return
    }

    // Check cache first
    let timeKey = String(format: "%.1f", time.seconds)
    if let cachedImage = thumbnailCache[timeKey] {
      completion(cachedImage)
      return
    }

    // Create image generator if needed
    if assetImageGenerator == nil {
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
      generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
      generator.maximumSize = CGSize(width: 320, height: 180)
      self.assetImageGenerator = generator
    }

    guard let generator = assetImageGenerator else {
      completion(nil)
      return
    }

    do {
      // Generate the thumbnail
      let imageRef = try await generator.image(at: time).image
      let image = UIImage(cgImage: imageRef)

      // Cache the result
      thumbnailCache[timeKey] = image

      completion(image)
    } catch {
      print("⚠️ Failed to generate thumbnail at \(time.seconds): \(error.localizedDescription)")
      completion(nil)
    }
  }
}

// MARK: - Video Player Manager Extensions

// Custom extension for VideoPlayerManager to fix fallback position issues
extension VideoPlayerManager {
  // Store a global static dictionary to preserve positions during fallbacks
  private static var fallbackPositions: [String: Double] = [:]
  private static var fallbackAttempts: [String: Int] = [:]
  private static var lastSceneWithFallback: String?

  // Enhanced method to preserve a position for fallback recovery
  func preservePositionForFallback(scene: StashScene, position: Double) {
    print(
      "🎯 CRITICAL: Preserving position \(formatTimeString(position)) for scene \(scene.id) in case of fallback"
    )

    // Store in multiple locations for redundancy
    VideoPlayerManager.fallbackPositions[scene.id] = position
    VideoPlayerManager.lastSceneWithFallback = scene.id
    VideoPlayerManager.fallbackAttempts[scene.id] = 0

    // Store in UserDefaults with multiple keys for redundancy
    UserDefaults.standard.set(position, forKey: "fallback_position_\(scene.id)")
    UserDefaults.standard.set(scene.id, forKey: "last_fallback_scene_id")
    UserDefaults.standard.set(position, forKey: "global_last_position")
    UserDefaults.standard.set(true, forKey: "has_pending_fallback_position")

    // Force synchronize to ensure values are saved immediately
    UserDefaults.standard.synchronize()

    print("🎯 Position \(formatTimeString(position)) preserved for scene \(scene.id)")
  }

  // Method to track fallback attempts
  func incrementFallbackAttempt(for sceneID: String) -> Int {
    let currentCount = VideoPlayerManager.fallbackAttempts[sceneID] ?? 0
    let newCount = currentCount + 1
    VideoPlayerManager.fallbackAttempts[sceneID] = newCount
    print("🔄 Fallback attempt #\(newCount) for scene \(sceneID)")
    return newCount
  }

  // Check if there's a fallback position for this scene
  func hasFallbackPosition(for sceneID: String) -> Bool {
    return VideoPlayerManager.fallbackPositions[sceneID] != nil
      || UserDefaults.standard.contains(key: "fallback_position_\(sceneID)")
  }

  // Helper function to format time within this extension
  private func formatTimeString(_ time: Double) -> String {
    let totalSeconds = Int(time)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }

  // Retrieve a fallback position with enhanced error recovery
  func getFallbackPosition(for sceneID: String) -> Double? {
    // Try memory cache first (most reliable)
    if let position = VideoPlayerManager.fallbackPositions[sceneID] {
      print("🎯 Retrieved fallback position from memory: \(formatTimeString(position))")
      return position
    }

    // Try UserDefaults next
    let defaultsKey = "fallback_position_\(sceneID)"
    if UserDefaults.standard.contains(key: defaultsKey) {
      let position = UserDefaults.standard.double(forKey: defaultsKey)
      if position > 0 {
        print("🎯 Retrieved fallback position from UserDefaults: \(formatTimeString(position))")
        // Save back to memory cache for future use
        VideoPlayerManager.fallbackPositions[sceneID] = position
        return position
      }
    }

    // Try global position as last resort
    if let lastSceneID = VideoPlayerManager.lastSceneWithFallback,
      lastSceneID == sceneID,
      UserDefaults.standard.contains(key: "global_last_position")
    {
      let position = UserDefaults.standard.double(forKey: "global_last_position")
      if position > 0 {
        print("🎯 Retrieved fallback position from global backup: \(formatTimeString(position))")
        return position
      }
    }

    print("⚠️ No fallback position found for scene \(sceneID)")
    return nil
  }

  // Clear fallback position after successful playback
  func clearFallbackPosition(for sceneID: String) {
    VideoPlayerManager.fallbackPositions[sceneID] = nil
    VideoPlayerManager.fallbackAttempts[sceneID] = nil
    if VideoPlayerManager.lastSceneWithFallback == sceneID {
      VideoPlayerManager.lastSceneWithFallback = nil
    }

    UserDefaults.standard.removeObject(forKey: "fallback_position_\(sceneID)")
    UserDefaults.standard.removeObject(forKey: "has_pending_fallback_position")

    print("🧹 Cleared fallback position for scene \(sceneID)")
  }

  // Legacy method name for backward compatibility - uses getFallbackPosition
  func getPreservedPosition(for sceneID: String) -> Double? {
    return getFallbackPosition(for: sceneID)
  }

  // Legacy method name for backward compatibility - uses clearFallbackPosition
  func clearPreservedPosition(for sceneID: String) {
    clearFallbackPosition(for: sceneID)
  }
}

// MARK: - Safe JSON Encoding Extension
extension Encodable {
  func toJSONSafeDictionary() -> [String: Any]? {
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(self)
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      return jsonObject as? [String: Any]
    } catch {
      print("❌ JSON encoding error: \(error)")
      return nil
    }
  }
}
