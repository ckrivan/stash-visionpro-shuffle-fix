import AVKit
import Combine
import RealityKit
import SwiftUI

struct VRVideoView: View {
  let scene: StashScene
  @Environment(\.dismiss) var dismiss
  @StateObject private var playerManager = VRPlayerManager()
  @State private var showControls = true
  @State private var hideControlsTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      // Video content
      if let player = playerManager.player {
        VideoPlayer(player: player)
          .ignoresSafeArea()
          .overlay {
            if playerManager.isLoading {
              ProgressView()
                .scaleEffect(2.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.5))
            }
          }
      } else if let error = playerManager.error {
        VStack {
          Text("Failed to load video")
            .foregroundStyle(.white)
          Text(error.localizedDescription)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }

      // Controls overlay
      if showControls {
        VStack {
          // Close button
          HStack {
            Button(action: {
              playerManager.cleanup()
              dismiss()
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .padding()
            }
            Spacer()
          }

          Spacer()

          // Progress controls
          VStack(spacing: 0) {
            // Progress bar
            Slider(
              value: Binding(
                get: { playerManager.currentTime },
                set: { newValue in
                  playerManager.seek(to: newValue)
                }
              ),
              in: 0...max(playerManager.duration, 1)
            )
            .tint(.white)
            .padding(.horizontal)

            // Time labels
            HStack {
              Text(formatTime(playerManager.currentTime))
                .font(.callout)
                .foregroundStyle(.white)
              Spacer()
              Text(formatTime(playerManager.duration))
                .font(.callout)
                .foregroundStyle(.white)
            }
            .padding(.horizontal)
          }
          .padding(.bottom)
          .background(
            LinearGradient(
              gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
        .transition(.opacity)
      }
    }
    .onTapGesture {
      withAnimation {
        showControls.toggle()
      }
      Task {
        await scheduleControlsHide()
      }
    }
    .task {
      print("🎬 VRVideoView appeared, setting up player")
      do {
        try await playerManager.setupPlayer(for: scene)
      } catch {
        print("❌ Error setting up player: \(error)")
        playerManager.error = error
      }
    }
    .onDisappear {
      print("🎬 VRVideoView disappeared, cleaning up")
      playerManager.cleanup()
    }
  }

  private func formatTime(_ time: Double) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func scheduleControlsHide() async {
    hideControlsTask?.cancel()
    hideControlsTask = Task {
      do {
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        if !Task.isCancelled {
          try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))  // Animation duration
          if !Task.isCancelled {
            await MainActor.run {
              withAnimation {
                showControls = false
              }
            }
          }
        }
      } catch {
        // Task was cancelled
      }
    }
  }
}

@MainActor
class VRPlayerManager: ObservableObject {
  @Published var player: AVPlayer?
  @Published var isLoading = true
  @Published var error: Error?
  @Published var currentTime: Double = 0
  @Published var duration: Double = 0
  @Published var errorMessage: String = ""

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

  func setupPlayer(for scene: StashScene) async throws {
    print("🎬 Setting up VR player for scene: \(scene.id)")

    // Clean up any existing player first
    cleanup()

    // Clean up any existing audio
    GlobalVideoManager.shared.muteAll()

    isLoading = true
    error = nil
    errorMessage = ""

    let api = StashAPI()

    // For VR content, use direct stream URL
    let streamURL = "\(api.serverAddress)/scene/\(scene.id)/stream?apikey=\(api.apiKey)"
    guard let url = URL(string: streamURL) else {
      let errorMsg = "Failed to construct stream URL"
      print("❌ \(errorMsg)")
      throw NSError(
        domain: "VRPlayerError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
    }

    print("🎬 Using VR stream URL: \(url.absoluteString)")

    // Create asset with headers
    let headers = [
      "Accept": "*/*",
      "Accept-Language": "en-US,en;q=0.9",
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
      "Connection": "keep-alive",
      "X-Playback-Session-Id": sessionId,
      "Origin": api.serverAddress,
      "Referer": "\(api.serverAddress)/scenes/\(scene.id)",
      "ApiKey": api.apiKey
    ]

    let asset = AVURLAsset(
      url: url,
      options: [
        "AVURLAssetHTTPHeaderFieldsKey": headers
      ])
    let playerItem = AVPlayerItem(asset: asset)
    playerItem.preferredForwardBufferDuration = 10

    // Create player
    let player = AVPlayer(playerItem: playerItem)
    player.automaticallyWaitsToMinimizeStalling = false

    // Set up player status observation
    statusObservation = playerItem.publisher(for: \.status)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        Task { @MainActor in
          switch status {
          case .failed:
            self?.error = playerItem.error
            self?.isLoading = false
          case .readyToPlay:
            self?.isLoading = false
            player.play()
          default:
            break
          }
        }
      }

    // Set up time observation
    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      Task { @MainActor in
        self?.currentTime = time.seconds
      }
    }

    // Observe current item for duration updates
    currentItemObservation = player.publisher(for: \.currentItem)
      .sink { [weak self] (item: AVPlayerItem?) in
        Task { @MainActor in
          self?.duration = item?.duration.seconds ?? 0
          self?.isLoading = item?.isPlaybackBufferEmpty ?? false
        }
      }

    // Observe buffer state
    bufferObservation = playerItem.publisher(for: \.isPlaybackBufferEmpty)
      .sink { [weak self] isEmpty in
        Task { @MainActor in
          self?.isLoading = isEmpty
        }
      }

    // Finally set the player
    self.player = player
  }

  func cleanup() {
    print("🎬 Cleaning up VR player")
    if let timeObserver = timeObserver {
      player?.removeTimeObserver(timeObserver)
    }

    timeObserver = nil
    itemObservation?.invalidate()
    itemObservation = nil
    statusObservation?.cancel()
    statusObservation = nil
    bufferObservation?.cancel()
    bufferObservation = nil
    stallObservation?.cancel()
    stallObservation = nil
    emptyBufferObservation?.cancel()
    emptyBufferObservation = nil
    likelyToKeepUpObservation?.cancel()
    likelyToKeepUpObservation = nil
    currentItemObservation?.cancel()
    currentItemObservation = nil

    player?.pause()
    player = nil
    isLoading = true
    error = nil
    currentTime = 0
    duration = 0
    errorMessage = ""
  }

  func seek(to time: Double) {
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
    player?.seek(to: cmTime)
  }
}
