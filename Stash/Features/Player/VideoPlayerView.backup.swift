import AVKit
import Combine
import ObjectiveC
import RealityKit
import SwiftUI

private class PlayerContainerView: UIView {
  weak var playerLayer: AVPlayerLayer?
  private var isSettingUp = false
  private var playerTimeControlStatusObserver: NSKeyValueObservation?

  override func layoutSubviews() {
    super.layoutSubviews()
    guard !isSettingUp else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    playerLayer?.frame = bounds
    CATransaction.commit()
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

    // Add debug info
    print("🎬 Player layer configuration:")
    print("  - Frame: \(layer.frame)")
    print("  - Video gravity: \(layer.videoGravity)")
    print("  - Draws asynchronously: \(layer.drawsAsynchronously)")

    // Add player layer to view
    self.layer.addSublayer(layer)
    self.playerLayer = layer

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
    return view
  }

  func updateUIView(_ uiView: PlayerContainerView, context: Context) {
    if uiView.playerLayer?.player !== player {
      print("🎬 Setting up player layer")
      Task { @MainActor in
        uiView.setupPlayer(player)
        // Force playback to start
        player.seek(to: .zero)
        player.play()
        player.playImmediately(atRate: 1.0)
      }
    }
  }

  static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
    print("🎬 Cleaning up player view")
    Task { @MainActor in
      uiView.setupPlayer(nil)
    }
  }
}

struct VideoPlayerViewBackup: View {
  let scene: StashScene
  @Environment(\.dismiss) var dismiss
  @StateObject private var playerManager = VideoPlayerManagerBackup()
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

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black.ignoresSafeArea()

        if let player = playerManager.player {
          ZStack(alignment: .bottom) {
            // Main video view
            VideoPlayerUIView(player: player)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .edgesIgnoringSafeArea(.all)
            // Custom controls
            if showControls {
              VideoControlsViewBackup(
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
              // Limit hit testing to the bottom area where controls actually are
              .contentShape(
                Rectangle().size(
                  CGSize(width: geometry.size.width, height: min(200, geometry.size.height * 0.3))
                ).offset(y: geometry.size.height * 0.7))
            }

            // Thumbnail overlay
            if isShowingThumbnail, let image = thumbnailImage {
              ThumbnailOverlayViewBackup(
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
                VideoControlsOverlayBackup(
                  playerManager: playerManager,
                  player: player,
                  playPureRandomVideo: handlePureRandomVideo,
                  playRandomVideo: handleRandomVideo,
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
                  .font(.system(size: 60, weight: .bold))
                  .foregroundColor(.white)
                  .padding(30)
                  .background(
                    RoundedRectangle(cornerRadius: 20)
                      .fill(Color.black.opacity(0.8))
                      .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 0)
                  )
              }
              .transition(.scale.combined(with: .opacity))
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .allowsHitTesting(false)
            }
          }
        } else if playerManager.isLoading {
          ZStack {
            VideoLoadingViewBackup()

            // Always visible emergency close button in top-right corner
            VStack {
              HStack {
                Spacer()
                Button(action: {
                  handleDismiss()
                }) {
                  Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
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
            VideoErrorViewBackup(error: error)

            // Always visible emergency close button in top-right corner
            VStack {
              HStack {
                Spacer()
                Button(action: {
                  handleDismiss()
                }) {
                  Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
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
    }
    .edgesIgnoringSafeArea(.all)
    .navigationBarHidden(true)
    .statusBarHidden(true)
    .task {
      await setupPlayer()
    }
    .onDisappear {
      cleanup()
    }
  }

  private func setupPlayer() async {
    // Make sure we don't run this more than once - this is critical
    if playerInitialized {
      print("⚠️ Player already initialized, skipping duplicate initialization")
      return
    }

    // Mark as initialized immediately to prevent duplicates
    playerInitialized = true

    // Determine the correct start time with minimal checks
    var startTime = appModel.videoStartTime

    // Quick check for app model start time
    if startTime == 0 && appModel.selectedSceneStartTime != nil {
      startTime = appModel.selectedSceneStartTime!
    }

    // Check UserDefaults only if needed
    if startTime == 0 {
      let savedStartTime = UserDefaults.standard.double(forKey: "last_video_start_time")
      let savedSceneId = UserDefaults.standard.string(forKey: "last_scene_id")

      if let savedId = savedSceneId, savedId == scene.id, savedStartTime > 0 {
        startTime = savedStartTime
      }
    }

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

  private func handleDismiss() {
    print("🎬 Starting player dismissal sequence")

    // First clean up all player resources
    cleanup()

    // Post notification that player is being dismissed
    NotificationCenter.default.post(name: .init("DismissVideoPlayer"), object: nil)

    // Use longer delay and do another round of cleanup before dismissal
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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

      // Finally dismiss the view
      dismiss()
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

    // Get thumbnail
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      withAnimation(.easeOut(duration: 0.2)) {
        self.isShowingThumbnail = false
      }
    }
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
      return false
    }

    // Find matching entry for this time
    guard
      let matchingEntry = playerManager.vttEntries.first(where: {
        time >= $0.startTime && time < $0.endTime
      })
    else {
      return false
    }

    print("🎬 Found VTT entry for time \(time): \(matchingEntry.startTime)-\(matchingEntry.endTime)")

    // Load sprite sheet if needed
    if playerManager.spriteSheetImage == nil {
      if let spriteUrl = VideoPlayerUtility.getSpriteURL(forSceneID: scene.id) {
        do {
          let (data, _) = try await URLSession.shared.data(from: spriteUrl)
          if let spriteImage = UIImage(data: data) {
            await MainActor.run {
              playerManager.spriteSheetImage = spriteImage
            }
          }
        } catch {
          print("❌ Error loading sprite sheet: \(error)")
          return false
        }
      } else {
        return false
      }
    }

    // Extract the thumbnail from the sprite sheet
    if let spriteImage = playerManager.spriteSheetImage {
      let rect = CGRect(
        x: matchingEntry.x, y: matchingEntry.y,
        width: matchingEntry.width, height: matchingEntry.height)

      if let cgImage = spriteImage.cgImage?.cropping(to: rect) {
        let thumbnail = UIImage(cgImage: cgImage)
        await MainActor.run {
          thumbnailImage = thumbnail
        }
        return true
      }
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

        // Get the first scene from the random results
        if let randomScene = api.scenes.first {
          // Reset any start time
          await MainActor.run {
            appModel.videoStartTime = 0
          }

          // Setup and start the player from the beginning
          await playerManager.setupPlayer(for: randomScene)

          // Keep controls hidden for seamless transition
          await MainActor.run {
            showControls = false
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

  // Random video at a random position
  private func playRandomVideo() {
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

        // Get the first scene from the random results
        if let randomScene = api.scenes.first {
          // Calculate a random start time
          var randomStartTime: Double = 0

          // Get the video duration
          let videoDuration = randomScene.files?.first?.duration ?? 0

          if videoDuration > 0 {
            // Calculate minimum of 5 minutes or video duration
            let minimumStartTime = min(5 * 60, videoDuration * 0.25)

            // Calculate maximum startTime (about 75% into the video to ensure enough content remains)
            let maximumStartTime = videoDuration * 0.75

            // Ensure we have enough playback time
            if maximumStartTime > minimumStartTime {
              // Generate random time between minimum and maximum
              randomStartTime = Double.random(in: minimumStartTime...maximumStartTime)
            } else {
              // Fall back to 5-minute mark or beginning if video is too short
              randomStartTime = videoDuration > 300 ? 300 : 0
            }
          }

          // Set the start time for the player
          await MainActor.run {
            appModel.videoStartTime = randomStartTime
          }

          // Setup and start the player with the random start time
          await playerManager.setupPlayer(for: randomScene, startTime: randomStartTime)

          // Keep controls hidden for seamless transition
          await MainActor.run {
            showControls = false
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

  // Enhanced feedback helper with animation
  private func showFeedback(_ message: String) {
    // Update the feedback message
    feedbackMessage = message

    // Show the feedback with animation
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      showingFeedback = true
    }

    // Hide feedback after 1.5 seconds
    Task {
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.3)) {
          showingFeedback = false
        }
      }
    }
  }
}

// MARK: - Loading and Error Views
private struct VideoLoadingViewBackup: View {
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

private struct VideoErrorViewBackup: View {
  let error: Error
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var playerManager: VideoPlayerManagerBackup
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
          playerManager.useHLS.toggle()

          isRetrying = true
          // Restart the player with the new streaming settings
          Task {
            if let scene = playerManager.currentScene {
              // We're reusing the scene and just changing streaming format
              await playerManager.setupPlayer(for: scene)
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
            Image(systemName: "xmark.circle.fill")
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

// MARK: - Thumbnail Overlay View
private struct ThumbnailOverlayViewBackup: View {
  let playerManager: VideoPlayerManagerBackup
  let isShowingThumbnail: Bool
  let thumbnailImage: UIImage?
  let thumbnailTime: Double
  let geometry: GeometryProxy

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
          x: geometry.size.width / 2,
          y: geometry.size.height / 2 - 80
        )
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: isShowingThumbnail)
  }
}

// MARK: - Video Controls View
private struct VideoControlsViewBackup: View {
  let playerManager: VideoPlayerManagerBackup
  let player: AVPlayer
  let showControls: Bool
  let geometry: GeometryProxy
  let onScrubbing: (DragGesture.Value, GeometryProxy) -> Void
  let onScrubEnd: (DragGesture.Value, GeometryProxy) -> Void
  let showFeedback: (String) -> Void
  let hideControls: () -> Void  // Added callback for hiding controls

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

        // Custom progress bar - VisionOS optimized with larger touch targets
        GeometryReader { scrubberGeometry in
          ZStack(alignment: .leading) {
            // Extra large track with buttons for timeline manipulation
            HStack(spacing: 0) {
              // Create 10 equal tap targets across the progress bar
              ForEach(0..<10) { i in
                // Individual segment covering 10% of timeline
                Rectangle()
                  .fill(Color.clear)
                  .frame(height: 100)  // Extra tall
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

            // Visual elements
            VStack(spacing: 0) {
              // Background track - significantly taller
              Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 30)  // Taller for better visibility and interaction
                .cornerRadius(15)

              // Progress fill
              Rectangle()
                .fill(Color.white)
                .frame(
                  width: calculateProgressWidth(
                    currentTime: playerManager.currentTime, duration: playerManager.duration,
                    totalWidth: scrubberGeometry.size.width), height: 30
                )
                .cornerRadius(15)
            }

            // Extra-large thumb indicator for VisionOS
            ZStack {
              // Glow effect
              Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 60, height: 60)
                .blur(radius: 8)

              // Thumb
              Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)  // Much larger for VisionOS hand tracking
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
            .position(
              x: calculateProgressWidth(
                currentTime: playerManager.currentTime, duration: playerManager.duration,
                totalWidth: scrubberGeometry.size.width), y: scrubberGeometry.size.height / 2
            )
            .hoverEffect(.highlight)  // Add VisionOS hover effect
          }
          // Add drag gesture for scrubbing
          .simultaneousGesture(  // Use simultaneousGesture instead of gesture for better compatibility
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                // Calculate position in timeline
                let position = max(0, min(value.location.x, scrubberGeometry.size.width))
                // Calculate the ratio of scrubber position
                let ratio = position / scrubberGeometry.size.width
                // Calculate time based on ratio
                let time = playerManager.duration * Double(ratio)

                // Update thumbnail preview
                onScrubbing(value, scrubberGeometry)

                // Live scrubbing - update position as you drag
                playerManager.currentTime = time

                // Show feedback while scrubbing
                self.showFeedback("⏱ \(playerManager.formatTime(time))")
              }
              .onEnded { value in
                // Calculate final position
                let position = max(0, min(value.location.x, scrubberGeometry.size.width))
                let ratio = position / scrubberGeometry.size.width
                let time = playerManager.duration * Double(ratio)

                // Seek to final position
                playerManager.seek(to: time)
                onScrubEnd(value, scrubberGeometry)
              }
          )
        }
        .frame(height: 80)  // Increased height for larger touch target
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
    -> CGFloat {
    let safeDuration = max(duration, 1.0)
    let progress = currentTime / safeDuration
    let width = CGFloat(progress) * totalWidth
    return max(0, min(width, totalWidth))
  }
}

struct VideoControlsOverlayBackup: View {
  let playerManager: VideoPlayerManagerBackup
  let player: AVPlayer
  let playPureRandomVideo: () -> Void
  let playRandomVideo: () -> Void
  let dismiss: () -> Void
  @State private var showStreamingOptions = false

  var body: some View {
    HStack(spacing: 35) {  // Increased spacing between buttons from 20 to 35
      // Close button
      Button(action: dismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 42))  // Increased from 30
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area

      // Pure random video button (picks a random video but starts from beginning)
      Button(action: playPureRandomVideo) {
        Image(systemName: "shuffle")
          .font(.system(size: 42))  // Increased from 30
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area

      // Random jump button (picks a random video and starts at a random position)
      Button(action: playRandomVideo) {
        Image(systemName: "shuffle.circle.fill")
          .font(.system(size: 42))  // Increased from 30
          .foregroundStyle(.purple)
          .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 0)
      }
      .buttonStyle(.plain)
      .padding(10)  // Add padding to increase tap area

      // Streaming mode toggle
      Button(action: {
        showStreamingOptions.toggle()
      }) {
        HStack(spacing: 6) {  // Slightly increased spacing
          Image(systemName: "network")
            .font(.system(size: 28))  // Increased from 18
          Text(playerManager.useHLS ? "HLS" : "Direct")
            .font(.system(size: 16, weight: .medium))  // Increased from caption
        }
        .padding(.horizontal, 12)  // Increased from 8
        .padding(.vertical, 8)  // Increased from 4
        .background(
          Capsule()
            .fill(Color.blue.opacity(0.6))
            .shadow(color: .black.opacity(0.5), radius: 3)
        )
        .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showStreamingOptions) {
        VStack(spacing: 12) {
          Text("Streaming Mode")
            .font(.headline)

          // Local state to hold the selection
          let isHLS = Binding<Bool>(
            get: { playerManager.useHLS },
            set: { playerManager.useHLS = $0 }
          )

          Picker("Streaming Mode", selection: isHLS) {
            Text("Direct").tag(false)
            Text("HLS").tag(true)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal)

          Button("Apply & Restart") {
            showStreamingOptions = false
            // Restart playback with current settings
            if let scene = playerManager.currentScene {
              Task {
                await playerManager.setupPlayer(for: scene)
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 5)
        }
        .padding()
        .frame(width: 200)
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
class VideoPlayerManagerBackup: NSObject, ObservableObject {
  @Published var player: AVPlayer?
  @Published var isLoading = true
  @Published var error: Error?
  @Published var currentTime: Double = 0
  @Published var duration: Double = 0
  @Published var errorMessage: String = ""
  @Published var thumbnailCache: [String: UIImage] = [:]
  @Published var vttEntries: [VideoPlayerUtility.VTTEntry] = []
  @Published var spriteSheetImage: UIImage?
  @Published var useHLS: Bool = false  // Flag for HLS streaming mode
  @Published var currentScene: StashScene?  // Store the current scene for retry operations

  // Audio duplication tracking - new property to store the current audio session ID
  private var currentSessionId = UUID().uuidString

  private var timeObserver: Any?
  private var itemObservation: NSKeyValueObservation?
  private var seekTime: Double?
  private let sessionId = UUID().uuidString
  private var statusObservation: AnyCancellable?
  private var bufferObservation: AnyCancellable?
  private var stallObservation: AnyCancellable?
  private var emptyBufferObservation: AnyCancellable?
  private var likelyToKeepUpObservation: AnyCancellable?
  private var currentItemObservation: AnyCancellable?
  private var assetImageGenerator: AVAssetImageGenerator?
  private var playerItemStatusObserver: NSKeyValueObservation?

  func setupPlayer(for scene: StashScene, startTime: Double? = nil) async {
    print("🎬 Setting up player for scene: \(scene.id)")

    // Clean up any existing player first
    cleanup()

    // Use aggressive audio cleanup to prevent any echoing
    GlobalVideoManager.shared.forceStopAllAudio()

    await MainActor.run {
      isLoading = true
      error = nil
      errorMessage = ""
      thumbnailCache.removeAll()
      assetImageGenerator = nil
      currentScene = scene  // Store the current scene for possible retry
    }

    let api = StashAPI()

    // Add a slight delay to ensure audio has been fully cleaned up
    do {
      try await Task.sleep(nanoseconds: 300_000_000)  // 300ms delay
      print("🎬 Audio cleanup pause complete, proceeding with player setup")
    } catch {
      print("⚠️ Sleep was interrupted: \(error)")
    }

    // Use the object property for useHLS flag, so it can be toggled by UI
    var attemptCount = 0
    var setupSuccess = false

    // Debug log the current stream format
    print("🎬 Initial streaming format: \(self.useHLS ? "HLS" : "Direct")")

    while attemptCount < 2 && !setupSuccess {
      attemptCount += 1

      guard
        let request = await api.getStreamRequest(
          forSceneID: scene.id, useHLS: self.useHLS, startTime: startTime)
      else {
        let errorMsg = "Failed to construct stream URL"
        print("❌ \(errorMsg)")

        // Only try the alternate format on first attempt
        if attemptCount == 1 {
          self.useHLS.toggle()
          print("🔄 Toggling streaming mode to \(self.useHLS ? "HLS" : "direct") automatically")
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
        headers["Accept-Language"] = "en-US,en;q=0.9"
        headers["Connection"] = "keep-alive"
        headers["X-Playback-Session-Id"] = currentSessionId

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
          "AVURLAssetHTTPMayUsePipeliningKey": NSNumber(value: true)
        ]

        let asset = AVURLAsset(url: url, options: assetOptions)

        // Create and configure the player item with more resilient settings
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 30
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        // Better async timeout system so we don't get stuck
        var loadingTimedOut = false

        // Create timeout task
        let timeoutTask = Task {
          try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 second timeout
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

              // Single playback initiation with seek if needed
              if let startTime = startTime {
                let time = CMTime(seconds: startTime, preferredTimescale: 600)
                do {
                  // Seek first, then play once
                  try await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                  print("✅ Seeked to time: \(self.formatTime(startTime))")
                  // Only play once after seeking
                  player.play()
                  print("▶️ Started playback after seeking to \(self.formatTime(startTime))")
                } catch {
                  print("⚠️ Seek failed, starting from beginning: \(error)")
                  player.play()
                  print("▶️ Started playback from beginning")
                }
              } else {
                // No startTime, just play once from beginning
                player.play()
                print("▶️ Started playback from beginning")
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

        // Set up time observation
        timeObserver = player.addPeriodicTimeObserver(
          forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
          queue: .main
        ) { [weak self] time in
          Task { @MainActor in
            guard let self = self else { return }
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

  // Handle KVO notifications for playback stalls
  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "playbackLikelyToKeepUp" {
      if let item = object as? AVPlayerItem, !item.isPlaybackLikelyToKeepUp {
        print("⚠️ Playback not likely to keep up - buffer issues")
        // Will attempt to recover naturally
      }
    } else if keyPath == "playbackBufferEmpty" {
      if let item = object as? AVPlayerItem, item.isPlaybackBufferEmpty {
        print("⚠️ Playback buffer empty")
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

  func cleanup() {
    print("🧹 Performing thorough player cleanup")

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
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        player.replaceCurrentItem(with: nil)
      }

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

    // Reset all state completely
    player = nil
    currentTime = 0
    duration = 0
    error = nil
    errorMessage = ""
    thumbnailCache.removeAll()
    vttEntries.removeAll()
    spriteSheetImage = nil

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

    // Use proper CMTime with high precision
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)

    // Use precise seeking for better results
    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
      guard let self = self, finished else { return }

      // Force update current time after seek
      Task { @MainActor in
        self.currentTime = time

        // Ensure playback continues after seeking
        if player.timeControlStatus != .playing {
          player.play()
        }
      }
    }
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

// MARK: - Safe JSON Encoding Extension
extension Encodable {
  func toJSONSafeDictionaryBackup() -> [String: Any]? {
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
