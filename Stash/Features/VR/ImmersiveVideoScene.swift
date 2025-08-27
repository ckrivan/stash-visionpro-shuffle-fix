import AVFoundation
import Combine
import Observation
import RealityKit
import SwiftUI
import UIKit

// Helper class to monitor app state changes
class AppStateMonitor: ObservableObject {
  var onBackgroundHandler: (() -> Void)?

  init() {
    // Set up notification observers for app state changes
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }

  @objc func appDidEnterBackground() {
    onBackgroundHandler?()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

// Helper class to monitor player status
class PlayerMonitor {
  private var timeObserverToken: Any?
  private var itemObserver: NSKeyValueObservation?
  private var statusObserver: NSKeyValueObservation?
  private var timeControlStatusObserver: NSKeyValueObservation?
  private var likelyToKeepUpObserver: NSKeyValueObservation?
  private var playerBufferEmptyObserver: NSKeyValueObservation?
  private var loadedTimeRangesObserver: NSKeyValueObservation?
  private var cancellables = Set<AnyCancellable>()

  weak var player: AVPlayer?

  init(
    player: AVPlayer, onPlaybackStalled: @escaping () -> Void,
    onBuffering: @escaping (Double) -> Void
  ) {
    self.player = player

    // Monitor status for debugging
    statusObserver = player.observe(\.status, options: [.new, .old]) { player, _ in
      let status = player.status
      print("🎬 Player status changed to: \(status.rawValue)")
      if status == .failed, let error = player.error {
        print("❌ Player error: \(error.localizedDescription)")
      }
    }

    // Monitor time control status to handle buffering states
    timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) {
      player, _ in
      switch player.timeControlStatus {
      case .playing:
        print("▶️ Player is playing")
      case .paused:
        print("⏸️ Player is paused")
      case .waitingToPlayAtSpecifiedRate:
        print("⏳ Player is buffering or waiting to play")
        // If player is waiting too long, try to recover
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            print("🔄 Player stuck buffering, attempting recovery")
            onPlaybackStalled()
          }
        }
      @unknown default:
        break
      }
    }

    // Monitor if player is likely to keep up
    if let playerItem = player.currentItem {
      likelyToKeepUpObserver = playerItem.observe(
        \.isPlaybackLikelyToKeepUp, options: [.new, .old]
      ) { item, _ in
        print("🎬 Playback likely to keep up: \(item.isPlaybackLikelyToKeepUp)")
        if !item.isPlaybackLikelyToKeepUp {
          // If buffer is too low, consider recovery action
          print("⚠️ Buffer may be low, monitoring...")
        }
      }

      // Monitor buffer empty states
      playerBufferEmptyObserver = playerItem.observe(
        \.isPlaybackBufferEmpty, options: [.new, .old]
      ) { item, _ in
        if item.isPlaybackBufferEmpty {
          print("⚠️ Playback buffer empty")
          if player.timeControlStatus != .playing {
            print("🔄 Attempting to restart playback after buffer empty")
            player.play()
          }
        }
      }

      // Monitor loaded time ranges to track buffering progress
      loadedTimeRangesObserver = playerItem.observe(\.loadedTimeRanges, options: [.new]) {
        item, _ in
        // Calculate buffer progress
        if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
          let bufferedDuration = timeRange.duration.seconds
          let bufferedStart = timeRange.start.seconds
          let bufferedEnd = bufferedStart + bufferedDuration

          // Current playback time
          let currentTime = player.currentTime().seconds

          // Calculate buffered ahead time (how much is buffered ahead of current playback)
          let bufferedAheadTime = bufferedEnd - currentTime

          print(
            "🧪 Buffer: \(Int(bufferedAheadTime))s ahead, range: \(bufferedStart)-\(bufferedEnd)s")
          onBuffering(bufferedAheadTime)
        }
      }
    }

    // Add periodic time observer to monitor playback progress
    let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      // Update time display or monitor for jumps/stalls
      let currentTime = time.seconds
      let duration = player.currentItem?.duration.seconds ?? 0

      // Detect if player is stuck at a specific time
      // Handled through combination of other observers
    }
  }

  func cleanup() {
    if let token = timeObserverToken, let player = player {
      player.removeTimeObserver(token)
      timeObserverToken = nil
    }

    statusObserver?.invalidate()
    timeControlStatusObserver?.invalidate()
    likelyToKeepUpObserver?.invalidate()
    playerBufferEmptyObserver?.invalidate()
    loadedTimeRangesObserver?.invalidate()

    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  deinit {
    cleanup()
  }
}

enum VRFormat: String, CaseIterable {
  case sideBySide = "Side-by-Side"
  case overUnder = "Over-Under"
  case mono = "Mono (Not VR)"

  var description: String {
    return self.rawValue
  }
}

struct ImmersiveVideoScene: View {
  @EnvironmentObject var appModel: AppModel
  @Environment(\.openImmersiveSpace) var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
  // App lifecycle management
  @StateObject private var appStateMonitor = AppStateMonitor()

  // State for video player
  @State private var videoPlayer: AVPlayer?
  @State private var videoMaterial: VideoMaterial?
  @State private var sphereEntity: ModelEntity?
  @State private var rootEntity = Entity()
  @State private var playerMonitor: PlayerMonitor?

  // Debug and control state
  @State private var debugMessage: String = "Initializing..."
  @State private var showControls = true
  @State private var showDebugOverlay = false
  @State private var hideControlsTask: Task<Void, Never>?
  @State private var vrFormat: VRFormat = .sideBySide
  @State private var sphereRadius: Float = 6.0  // More comfortable viewing distance
  @State private var eyeOffset: Float = 0.063  // Standard IPD (63mm)
  @State private var fov: Float = 160.0  // Slightly less than 180 to avoid distortion at edges
  @State private var rotation: Float = 0.0  // Rotation around Y axis
  @State private var verticalOffset: Float = -0.3  // Slight downward positioning
  @State private var showGuide: Bool = true  // Show initial guide on first launch
  @State private var bufferingProgress: Double = 0.0
  @State private var isRecoveryInProgress = false

  // API for fetching random scenes
  @StateObject private var api = StashAPI()
  @State private var isShuffling = false

  // Shuffle to a random scene
  private func shuffleVideo() {
    guard !isShuffling else { return }
    isShuffling = true
    Task {
      do {
        try await api.fetchScenes(page: 1, sort: "random")
        if let randomScene = api.scenes.first {
          await MainActor.run {
            appModel.currentScene = randomScene
            debugMessage += "\nShuffled to: \(randomScene.title ?? "Untitled")"
          }
        }
      } catch {
        await MainActor.run {
          debugMessage += "\nShuffle failed: \(error.localizedDescription)"
        }
      }
      isShuffling = false
    }
  }

  // Play a random video with a random starting point
  private func playRandomVideo() async {
    guard !isShuffling else { return }
    isShuffling = true

    Task {
      do {
        // Get a random scene
        try await api.fetchScenes(page: 1, sort: "random")

        guard let randomScene = api.scenes.first else {
          debugMessage = "No videos found to shuffle to"
          isShuffling = false
          return
        }

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

        await MainActor.run {
          // Set the new scene as current scene
          appModel.currentScene = randomScene

          // Clean up current playback resources
          cleanupResources()

          // Dismiss current immersive space
          Task {
            try? await dismissImmersiveSpace()

            // Wait a moment to ensure clean transition
            try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

            // Open new immersive space
            try? await openImmersiveSpace(id: "ImmersiveVideoSpace")

            // Set the start time for the new video
            appModel.videoStartTime = randomStartTime

            debugMessage =
              "Playing random video: \(randomScene.title ?? "Untitled")\nStarting at: \(Int(randomStartTime / 60))m \(Int(randomStartTime.truncatingRemainder(dividingBy: 60)))s"
          }
        }
      } catch {
        debugMessage = "Failed to shuffle video: \(error.localizedDescription)"
      }

      isShuffling = false
    }
  }

  var body: some View {
    RealityView { content in
      content.add(rootEntity)
      debugMessage = "Root entity added to content"

      // Check if we have a current scene
      guard let currentScene = appModel.currentScene else {
        debugMessage = "No current scene selected"
        return
      }

      debugMessage = "Loading scene: \(currentScene.id)"

      // Determine VR format from tags
      let tagNames = currentScene.tags?.map { $0.name.lowercased() } ?? []
      debugMessage += "\nTags: \(tagNames.joined(separator: ", "))"

      // Consider all videos in VR library as VR content
      let isVRContent = true

      let isOverUnder = tagNames.contains {
        $0.contains("over-under") || $0.contains("tb") || $0.contains("top-bottom")
          || $0.contains("topbottom")
      }

      let isSideBySide = tagNames.contains {
        $0.contains("side-by-side") || $0.contains("sbs") || $0.contains("lr")
          || $0.contains("left-right")
      }

      // Also check title for format hints
      let title = currentScene.title.lowercased()
      let titleIndicatesSBS =
        title.contains("sbs") || title.contains("side by side") || title.contains("side-by-side")
      let titleIndicatesOU =
        title.contains("tb") || title.contains("top bottom") || title.contains("over under")
        || title.contains("ou")

      // Set initial format based on detection
      if isOverUnder || titleIndicatesOU {
        vrFormat = .overUnder
        debugMessage += "\nDetected format: Over-Under"
      } else if isSideBySide || titleIndicatesSBS {
        vrFormat = .sideBySide
        debugMessage += "\nDetected format: Side-by-Side"
      } else if isVRContent {
        vrFormat = .sideBySide  // Default to side-by-side for VR content
        debugMessage += "\nDefault to Side-by-Side for VR content"
      } else {
        vrFormat = .mono
        debugMessage += "\nDetected format: Mono (Not VR)"
      }

      // Store a local reference to content to avoid capturing the inout parameter
      let contentRef = content

      // Set up video player
      Task {
        do {
          let api = StashAPI()
          // For VR content, always use direct streaming
          guard let request = await api.getStreamRequest(forSceneID: currentScene.id, useHLS: false)
          else {
            debugMessage += "\nFailed to get stream request"
            return
          }

          guard let url = request.url else {
            debugMessage += "\nInvalid stream URL"
            return
          }

          debugMessage += "\nStreaming URL: \(url.absoluteString)"
          print("🎬 Streaming VR video from: \(url.absoluteString)")

          // Create asset with request headers and more robust configuration
          let asset = AVURLAsset(
            url: url,
            options: [
              "AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:],
              "AVURLAssetOutOfBandMIMETypeKey": "video/mp4",
              "AVURLAssetAllowsExpensiveNetworkAccess": true,
              "AVURLAssetAllowsConstrainedNetworkAccess": true
            ])

          // Create a more robust player item with prefetched resources
          let playerItem = AVPlayerItem(asset: asset)

          // Improve buffering behavior
          playerItem.preferredForwardBufferDuration = 10  // Buffer 10 seconds ahead
          playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

          // Set up player with improved configuration
          let player = AVPlayer(playerItem: playerItem)
          player.automaticallyWaitsToMinimizeStalling = false  // Start playback sooner
          // Note: allowsExternalPlayback is not available in visionOS
          print("🎬 Created player instance with enhanced settings")

          // Monitor playback status with KVO
          debugMessage += "\nSetting up KVO observations for player"

          // Prepare the player item for playback
          await playerItem.asset.loadValues(forKeys: ["playable", "duration"])
          let isPlayable = (try? await playerItem.asset.load(.isPlayable)) ?? false
          let duration = (try? await playerItem.asset.load(.duration).seconds) ?? 0.0
          print("🎬 Video is playable: \(isPlayable), duration: \(duration) seconds")

          // Get video dimensions if available
          do {
            // Use loadTracks instead of tracks which is unavailable in visionOS
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
              let dimensions = videoTrack.naturalSize
              let aspectRatio = dimensions.width / dimensions.height
              debugMessage +=
                "\nVideo dimensions: \(dimensions.width) x \(dimensions.height), AR: \(aspectRatio)"

              // Auto-detect format based on aspect ratio if not already determined
              if vrFormat == .sideBySide && aspectRatio < 1.0 {
                vrFormat = .overUnder
                debugMessage += "\nSwitched to Over-Under based on aspect ratio"
              } else if vrFormat == .overUnder && aspectRatio > 2.0 {
                vrFormat = .sideBySide
                debugMessage += "\nSwitched to Side-by-Side based on aspect ratio"
              }
            }
          } catch {
            debugMessage += "\nError loading video tracks: \(error.localizedDescription)"
          }

          await MainActor.run {
            print("🎬 Setting up VR player on MainActor")
            videoPlayer = player

            // Make sure playback starts
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .pause

            // Create spherical video surface
            createVideoSphere(in: contentRef)
            print("🎬 Video sphere created, starting playback")

            // Set up player monitor to detect and handle playback issues
            playerMonitor = PlayerMonitor(
              player: player,
              onPlaybackStalled: {
                Task { @MainActor in
                  await self.recoverFromStall()
                }
              },
              onBuffering: { bufferTime in
                Task { @MainActor in
                  self.bufferingProgress = bufferTime

                  // If buffer is good, but player is stalled, try to restart
                  if bufferTime > 5 && player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    if !self.isRecoveryInProgress {
                      print("⚠️ Buffer looks good but player is waiting, attempting recovery")
                      await self.recoverFromStall()
                    }
                  }
                }
              }
            )

            // Start playback with a slight delay to ensure planes are ready
            Task {
              try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

              // Check if we need to start at a specific time
              if appModel.videoStartTime > 0 {
                // Convert to CMTime
                let startTime = CMTime(seconds: appModel.videoStartTime, preferredTimescale: 1000)

                // Seek to the start time
                player.seek(to: startTime) { finished in
                  if finished {
                    player.play()
                    print("🎬 Player started at position: \(self.appModel.videoStartTime) seconds")
                  }
                }

                // Reset the start time for next video
                appModel.videoStartTime = 0
              } else {
                // Start from beginning if no specific start time
                player.play()
                print("🎬 Player.play() called from beginning")
              }

              // Set up a playback monitor timer
              await self.startPlaybackMonitorTimer()
            }

            // Initially show controls and schedule auto-hide
            showControls = true
            showGuide = true
            Task {
              await scheduleControlsHide()
            }
          }
        } catch {
          debugMessage += "\nError setting up video: \(error.localizedDescription)"
        }
      }
    } update: { content in
      // Update video sphere when format changes
      if let videoPlayer = videoPlayer {
        updateVideoSphere(in: content)
      }
    }
    .ignoresSafeArea()
    // Listen for app state changes
    .onAppear {
      appStateMonitor.onBackgroundHandler = {
        cleanupResources()
        Task {
          try? await dismissImmersiveSpace()
        }
        print("🎬 Video paused due to app entering background")
      }
    }
    .onDisappear {
      cleanupResources()
    }
    // Main tap gesture to toggle controls
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.3)) {
        showControls.toggle()
      }

      Task {
        await scheduleControlsHide()
      }
    }
    // Add gesture handlers for the immersive experience
    .gesture(
      // Rotate left/right
      DragGesture()
        .onChanged { value in
          // Convert drag to rotation
          let rotationDelta = Float(value.translation.width) * 0.01
          rotation += rotationDelta

          // Update sphere orientation
          sphereEntity?.orientation = .init(angle: rotation, axis: [0, 1, 0])

          // Show controls when gesturing
          withAnimation {
            showControls = true
          }
          Task {
            await scheduleControlsHide()
          }
        }
    )
    .overlay(alignment: .bottom) {
      // Main control overlay (conditionally visible)
      if showControls {
        VStack(spacing: 0) {
          // Buffering indicator (appears when needed)
          if videoPlayer?.timeControlStatus == .waitingToPlayAtSpecifiedRate || isRecoveryInProgress {
            HStack(spacing: 10) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

              Text(isRecoveryInProgress ? "Recovering playback..." : "Buffering...")
                .foregroundColor(.white)

              if bufferingProgress > 0 {
                Text("\(Int(bufferingProgress))s buffered")
                  .foregroundColor(.white.opacity(0.8))
                  .font(.caption)
              }
            }
            .padding(8)
            .background(.ultraThinMaterial.opacity(0.7))
            .cornerRadius(12)
            .padding(.bottom, 8)
          }

          // Playback controls
          HStack(spacing: 20) {
            // Exit button
            Button(action: {
              Task {
                cleanupResources()
                try? await dismissImmersiveSpace()
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // Play/Pause button
            Button(action: {
              if videoPlayer?.timeControlStatus == .playing {
                videoPlayer?.pause()
              } else {
                videoPlayer?.play()
              }
            }) {
              Image(
                systemName: videoPlayer?.timeControlStatus == .playing
                  ? "pause.circle.fill" : "play.circle.fill"
              )
              .font(.system(size: 40))
              .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // Format selector - Quick toggle between SBS and OU
            Button(action: {
              if vrFormat == .sideBySide {
                vrFormat = .overUnder
              } else if vrFormat == .overUnder {
                vrFormat = .sideBySide
              } else {
                vrFormat = .sideBySide  // Default to SBS
              }
            }) {
              HStack {
                Text(vrFormat.description)
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.ultraThinMaterial)
              .cornerRadius(16)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Status indicator for player
            if !isRecoveryInProgress && videoPlayer?.timeControlStatus == .playing {
              HStack(spacing: 4) {
                Circle()
                  .fill(Color.green)
                  .frame(width: 8, height: 8)
                Text("Playing")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.8))
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.ultraThinMaterial.opacity(0.5))
              .cornerRadius(16)
            }

            // Random Jump Button
            Button(action: {
              Task {
                await playRandomVideo()
              }
            }) {
              HStack {
                Image(systemName: "shuffle")
                Text("Random Jump")
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(.purple.opacity(0.7))
              .cornerRadius(16)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .disabled(isShuffling)

            // Adjust/Debug button
            Button(action: {
              showDebugOverlay.toggle()
            }) {
              Text(showDebugOverlay ? "Hide Controls" : "Adjust View")
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          .padding()
          .background(
            LinearGradient(
              gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
              startPoint: .bottom,
              endPoint: .top
            ))

          // Advanced controls overlay (toggle visibility)
          if showDebugOverlay {
            VStack(alignment: .leading, spacing: 10) {
              Text("VR View Adjustments")
                .font(.headline)

              Picker("Format", selection: $vrFormat) {
                ForEach(VRFormat.allCases, id: \.self) { format in
                  Text(format.description).tag(format)
                }
              }
              .pickerStyle(.segmented)

              HStack {
                Text("Distance: \(sphereRadius, specifier: "%.1f")m")
                Slider(value: $sphereRadius, in: 4...10, step: 0.5)
              }

              HStack {
                Text("Field of View: \(fov, specifier: "%.0f")°")
                Slider(value: $fov, in: 120...180, step: 5)
              }

              HStack {
                Text("Height: \(verticalOffset, specifier: "%.1f")m")
                Slider(value: $verticalOffset, in: -1.0...1.0, step: 0.1)
              }

              // Gesture explanation text
              Text("Gestures: Drag left/right to rotate • Tap to show/hide controls")
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .frame(maxWidth: 400)
            .padding()
          }
        }
      }

      // Initial guide overlay
      if showGuide {
        VStack {
          Spacer()

          VStack(spacing: 16) {
            Text("VR Video Controls")
              .font(.title2)
              .bold()

            VStack(alignment: .leading, spacing: 10) {
              Label("Tap screen to show/hide controls", systemImage: "hand.tap")
              Label("Drag left/right to rotate view", systemImage: "arrow.left.and.right")
              Label(
                "Format button switches between Side-by-Side and Over-Under",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
              Divider()
              Label(
                "Use the 'Random Jump' button to shuffle to a random video starting at a random position",
                systemImage: "shuffle"
              )
              .foregroundColor(.purple)
              .fontWeight(.medium)
            }
            .font(.body)

            Button("Got it!") {
              withAnimation {
                showGuide = false
              }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
          }
          .padding()
          .frame(maxWidth: 500)
          .background(.ultraThinMaterial)
          .cornerRadius(20)
          .padding(30)

          Spacer()
        }
        .transition(.opacity)
      }
    }
  }

  private func scheduleControlsHide() async {
    // Force controls to be visible
    if !showControls {
      await MainActor.run {
        withAnimation {
          showControls = true
        }
      }
    }

    // Cancel any pending hide tasks
    hideControlsTask?.cancel()

    // Don't auto-hide controls for the first 30 seconds after a show action
    // Only schedule auto-hide if showGuide is false (user has acknowledged the guide)
    if !showGuide {
      hideControlsTask = Task {
        do {
          try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
          if !Task.isCancelled {
            await MainActor.run {
              withAnimation {
                showControls = false
              }
            }
          }
        } catch {
          // Task was cancelled
        }
      }
    }
  }

  // MARK: - Playback Monitoring and Recovery

  // Playback monitoring state
  @State private var playbackMonitorTimer: Timer?
  @State private var lastPlaybackTime: Double = 0
  @State private var stalledTimeCount: Int = 0

  @MainActor
  private func startPlaybackMonitorTimer() async {
    // Clean up existing timer if any
    playbackMonitorTimer?.invalidate()

    // Store self as unowned since Timer doesn't need to be weak for a struct
    let selfRef = self

    // Create a new timer that fires every 2 seconds
    playbackMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
      guard let player = selfRef.videoPlayer else { return }

      let currentTime = player.currentTime().seconds
      let lastTime = selfRef.lastPlaybackTime

      // If playback hasn't advanced in 6 seconds (3 checks), try recovery
      if abs(currentTime - lastTime) < 0.1 {
        Task { @MainActor in
          let newCount = selfRef.stalledTimeCount + 1
          selfRef.stalledTimeCount = newCount
          print("⚠️ Playback may be stalled at \(currentTime)s (\(newCount)/3)")

          if newCount >= 3 {
            print("🔄 Playback stalled for too long, attempting recovery")
            await selfRef.recoverFromStall()
            selfRef.stalledTimeCount = 0
          }
        }
      } else {
        // Playback is moving, reset stalled counter
        Task { @MainActor in
          selfRef.stalledTimeCount = 0
        }
      }

      // Update last playback time
      Task { @MainActor in
        selfRef.lastPlaybackTime = currentTime
      }
    }
  }

  private func stopPlaybackMonitorTimer() {
    playbackMonitorTimer?.invalidate()
    playbackMonitorTimer = nil
  }

  private func recoverFromStall() async {
    guard let player = videoPlayer, !isRecoveryInProgress else { return }

    // Update state on MainActor
    await MainActor.run {
      isRecoveryInProgress = true
      debugMessage += "\nAttempting to recover from playback stall..."
    }
    print("🔄 Running playback recovery procedure")

    // Get current playback position
    let currentTime = player.currentTime()

    // Try several recovery strategies

    // 1. First try simply resuming playback
    print("🔄 Recovery step 1: Resume playback")
    player.play()

    // Wait to see if that helped
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

    // 2. If still stalled, try seeking slightly forward
    if player.timeControlStatus != .playing {
      print("🔄 Recovery step 2: Seek forward slightly")
      let newTime = CMTimeAdd(currentTime, CMTime(seconds: 1.0, preferredTimescale: 1000))
      player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
        player.play()
      }

      // Wait to see if that helped
      try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
    }

    // 3. If still stalled, try reloading the player item
    if player.timeControlStatus != .playing {
      print("🔄 Recovery step 3: Reload player item")

      // Get the existing item's asset and time
      if let currentItem = player.currentItem,
        let asset = currentItem.asset as? AVURLAsset {
        // Create a new item with the same asset
        let newItem = AVPlayerItem(asset: asset)
        newItem.preferredForwardBufferDuration = 20  // Increase buffer

        // Replace the item
        await MainActor.run {
          player.replaceCurrentItem(with: newItem)
        }

        // Seek to previous position and play
        await MainActor.run {
          player.seek(to: currentTime)
          player.play()
        }
      }
    }

    // Reset recovery flag after waiting a bit
    try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

    // Update state on MainActor
    await MainActor.run {
      isRecoveryInProgress = false
    }
  }

  private func cleanupResources() {
    print("🧹 Cleaning up VR video resources")

    // Stop the playback monitor
    stopPlaybackMonitorTimer()

    // Clean up player monitor
    playerMonitor?.cleanup()
    playerMonitor = nil

    // Explicitly pause, clear source, and release video player
    if let player = videoPlayer {
      // Pause first
      player.pause()

      // Reset player item to fully stop audio
      player.replaceCurrentItem(with: nil)

      // Set volume to ensure no lingering audio
      player.volume = 0
      player.isMuted = true
    }

    // Clear reference
    videoPlayer = nil

    // Clean up video material
    videoMaterial = nil

    // Clean up entities
    sphereEntity?.removeFromParent()
    sphereEntity = nil

    // Reset state flags
    isRecoveryInProgress = false

    // Stop all previews to ensure all audio is silenced
    GlobalVideoManager.shared.stopAllPreviews()

    print("🧹 VR video resources cleaned up")
  }
}

// MARK: - Spherical Video Generation (MoonPlayer-inspired approach)
extension ImmersiveVideoScene {
  private func createVideoSphere(in content: RealityViewContent) {
    guard let videoPlayer = videoPlayer else {
      debugMessage += "\nNo video player available"
      return
    }

    print("🎬 Creating VR video sphere with MoonPlayer-inspired approach")

    // Remove existing sphere
    sphereEntity?.removeFromParent()

    // Create video material
    do {
      // Create the video material
      print("🎥 Creating video material")
      videoMaterial = try VideoMaterial(avPlayer: videoPlayer)

      // Create plane mesh for simpler, more reliable approach
      // This creates a curved, wide plane that simulates a partial sphere
      createSimplifiedVideoSphere(in: content)

      debugMessage += "\nVideo plane created successfully"
      print("🎥 Video plane created successfully")
    } catch {
      debugMessage += "\nFailed to create video material: \(error.localizedDescription)"
      print("❌ Error creating video material: \(error.localizedDescription)")
    }
  }

  private func updateVideoSphere(in content: RealityViewContent) {
    // Recreate video sphere when format changes
    print("🎬 Updating video with new format: \(vrFormat.description)")
    createVideoSphere(in: content)

    // Make sure video is playing after format change
    if let player = videoPlayer, player.timeControlStatus != .playing {
      print("🎬 Restarting playback after format change")
      player.play()
    }
  }

  private func createSimplifiedVideoSphere(in content: RealityViewContent) {
    guard let videoMaterial = videoMaterial else { return }

    // Use a simplified approach that works more reliably on visionOS
    // Instead of a complete sphere, create a curved surface with correct UVs

    // Create a curved plane that fills most of the field of view
    let curvedPlane = createCurvedSurface(radius: sphereRadius, format: vrFormat)

    do {
      // Create mesh descriptor
      var meshDescriptor = MeshDescriptor()
      meshDescriptor.positions = MeshBuffer(curvedPlane.vertices)
      meshDescriptor.textureCoordinates = MeshBuffer(curvedPlane.uvs)
      meshDescriptor.primitives = .triangles(curvedPlane.indices)

      // Add normals for correct lighting
      meshDescriptor.normals = MeshBuffer(curvedPlane.normals)

      // Generate mesh resource
      let mesh = try MeshResource.generate(from: [meshDescriptor])

      // Create model entity with video material
      sphereEntity = ModelEntity(mesh: mesh, materials: [videoMaterial])

      // Position and orientation
      sphereEntity?.position = [0, verticalOffset, 0]
      sphereEntity?.orientation = .init(angle: rotation, axis: [0, 1, 0])

      // Add to root entity
      if let sphereEntity = sphereEntity {
        rootEntity.addChild(sphereEntity)
        print("✅ Video surface created and added to scene")
      }
    } catch {
      debugMessage += "\nError creating video surface: \(error.localizedDescription)"
      print("❌ Error creating video surface: \(error.localizedDescription)")
    }
  }

  // Create a curved surface for video viewing (like MoonPlayer)
  private func createCurvedSurface(radius: Float, format: VRFormat) -> (
    vertices: [SIMD3<Float>], uvs: [SIMD2<Float>], normals: [SIMD3<Float>], indices: [UInt32]
  ) {
    // Create a curved plane with more reliable UVs
    print("🔨 Creating curved surface for format: \(format)")

    // Vertical and horizontal segments (more segments = smoother curve)
    let vSegments = 16
    let hSegments = 32

    // Calculate the horizontal field of view in radians (180 degrees for a half-cylinder)
    let hFov = Float.pi * 0.8  // 144 degrees wide (good compromise)

    var vertices: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    // Create a curved plane
    for vIdx in 0...vSegments {
      // Vertical position from -0.6 to +0.6 (not full -1 to 1 to reduce distortion)
      let verticalPos = (Float(vIdx) / Float(vSegments) - 0.5) * 1.2

      for hIdx in 0...hSegments {
        // Horizontal angle from -hFov/2 to +hFov/2
        let angle = (Float(hIdx) / Float(hSegments) - 0.5) * hFov

        // Calculate position
        let x = radius * sin(angle)
        let y = radius * verticalPos
        let z = -radius * cos(angle)

        vertices.append([x, y, z])

        // Normal vector pointing toward viewer (inward direction)
        let normal = normalize(SIMD3<Float>(-x, 0, z))
        normals.append(normal)

        // Calculate UV coordinates based on format
        var texU: Float = 0
        var texV: Float = 0

        switch format {
        case .sideBySide:
          // Map to left half of the texture for SBS format
          texU = Float(hIdx) / Float(hSegments) * 0.5
          texV = 1.0 - Float(vIdx) / Float(vSegments)  // Flip V to match video orientation
        case .overUnder:
          // Map to top half of the texture for OU format
          texU = Float(hIdx) / Float(hSegments)
          texV = (1.0 - Float(vIdx) / Float(vSegments)) * 0.5
        case .mono:
          // Use full texture for mono
          texU = Float(hIdx) / Float(hSegments)
          texV = 1.0 - Float(vIdx) / Float(vSegments)
        }

        uvs.append([texU, texV])
      }
    }

    // Create triangle indices
    for vIdx in 0..<vSegments {
      for hIdx in 0..<hSegments {
        let topLeft = vIdx * (hSegments + 1) + hIdx
        let topRight = topLeft + 1
        let bottomLeft = (vIdx + 1) * (hSegments + 1) + hIdx
        let bottomRight = bottomLeft + 1

        // First triangle
        indices.append(UInt32(topLeft))
        indices.append(UInt32(bottomLeft))
        indices.append(UInt32(topRight))

        // Second triangle
        indices.append(UInt32(topRight))
        indices.append(UInt32(bottomLeft))
        indices.append(UInt32(bottomRight))
      }
    }

    print("🔨 Created curved surface with \(vertices.count) vertices and \(indices.count) indices")

    return (vertices, uvs, normals, indices)
  }
}
