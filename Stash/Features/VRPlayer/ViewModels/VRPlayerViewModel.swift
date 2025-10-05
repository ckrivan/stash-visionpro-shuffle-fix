import AVFoundation
import Combine
import RealityKit
import SwiftUI

@MainActor
class VRPlayerViewModel: ObservableObject {
  // MARK: - Published Properties

  // Player State
  @Published var player: AVPlayer?
  @Published var isPlaying = false
  @Published var isLoading = false
  @Published var error: Error?
  @Published var currentTime: TimeInterval = 0
  @Published var duration: TimeInterval = 0
  @Published var bufferProgress: Double = 0

  // Video Information
  @Published var currentVideo: XBVRVideo?
  @Published var videoFormat: XBVRVideo.StereoMode = .sideBySide
  @Published var videoType: XBVRVideo.VideoType = .vr180

  // Controls and UI
  @Published var showControls = true
  @Published var showAdjustmentPanel = false
  @Published var showSpatialControls = false
  @Published var isSeekingActive = false
  @Published var playbackRate: Float = 1.0

  // Settings
  @Published var videoAdjustments = VideoAdjustments()
  @Published var spatialSettings = SpatialSettings()
  @Published var selectedQuality: VideoQuality = .high

  // MARK: - Private Properties

  private let xbvrService: XBVRService
  private var timeObserver: Any?
  private var playerObservations = Set<AnyCancellable>()
  private var controlsHideTimer: Timer?

  // MARK: - Initialization

  init(xbvrService: XBVRService = .shared) {
    self.xbvrService = xbvrService
    setupBindings()
  }

  // Note: No deinit needed - cleanup() is called when player is dismissed

  // MARK: - Public Methods

  /// Loads and starts playing a video
  func loadVideo(_ video: XBVRVideo) async {
    cleanup()

    isLoading = true
    error = nil

    do {
      // Fetch full video details from XBVR to get actual stream URL
      print("🎬 Fetching full video details for: \(video.title)")
      let fullVideo = try await xbvrService.fetchVideo(id: video.id)

      currentVideo = fullVideo
      videoFormat = fullVideo.detectedStereoMode
      videoType = fullVideo.videoType

      print("🎬 Stream URL: \(fullVideo.streamURL.absoluteString)")

      // DeoVR API provides stream URL in the full scene response
      try await setupPlayer(with: fullVideo.streamURL)
      isLoading = false
    } catch {
      print("❌ Error loading video: \(error)")
      self.error = error
      isLoading = false
    }
  }

  /// Plays the current video
  func play() {
    player?.play()
    isPlaying = true
    scheduleControlsHide()
  }

  /// Pauses the current video
  func pause() {
    player?.pause()
    isPlaying = false
    cancelControlsHide()
  }

  /// Toggles play/pause state
  func togglePlayPause() {
    if isPlaying {
      pause()
    } else {
      play()
    }
  }

  /// Seeks to a specific time
  func seek(to time: TimeInterval) {
    let cmTime = CMTime(seconds: time, preferredTimescale: 600)
    isSeekingActive = true

    player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      Task { @MainActor in
        self?.isSeekingActive = false
      }
    }
  }

  /// Skips forward by specified seconds
  func skipForward(_ seconds: TimeInterval = 60) {
    let newTime = currentTime + seconds
    seek(to: min(newTime, duration))
  }

  /// Skips backward by specified seconds
  func skipBackward(_ seconds: TimeInterval = 30) {
    let newTime = currentTime - seconds
    seek(to: max(newTime, 0))
  }

  /// Changes playback rate
  func setPlaybackRate(_ rate: Float) {
    playbackRate = rate
    player?.rate = rate
  }

  /// Updates video format and recreates renderer
  func updateVideoFormat(_ format: XBVRVideo.StereoMode) {
    videoFormat = format
    // Trigger renderer update
    objectWillChange.send()
  }

  /// Applies video adjustments
  func applyVideoAdjustments(_ adjustments: VideoAdjustments) {
    videoAdjustments = adjustments
    // Trigger renderer update with new adjustments
    objectWillChange.send()
  }

  /// Applies spatial settings
  func applySpatialSettings(_ settings: SpatialSettings) {
    spatialSettings = settings
    // Trigger renderer update with new settings
    objectWillChange.send()
  }

  /// Resets all settings to defaults
  func resetSettings() {
    videoAdjustments = .default
    spatialSettings = .default
    objectWillChange.send()
  }

  /// Shows controls and schedules auto-hide
  func showControlsTemporarily() {
    showControls = true
    scheduleControlsHide()
  }

  /// Toggles controls visibility
  func toggleControls() {
    showControls.toggle()
    if showControls {
      scheduleControlsHide()
    } else {
      cancelControlsHide()
    }
  }

  /// Loads a random video
  func loadRandomVideo() async {
    do {
      let randomVideos = try await xbvrService.fetchRandomVideos(count: 1)
      if let randomVideo = randomVideos.first {
        await loadVideo(randomVideo)
      }
    } catch {
      self.error = error
    }
  }

  // MARK: - Private Methods

  private func setupBindings() {
    // Monitor spatial settings changes
    $spatialSettings
      .dropFirst()
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: &playerObservations)

    // Monitor video adjustments changes
    $videoAdjustments
      .dropFirst()
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: &playerObservations)
  }

  private func setupPlayer(with url: URL) async throws {
    // Create player item with enhanced buffering
    let asset = AVURLAsset(url: url)
    let playerItem = AVPlayerItem(asset: asset)
    playerItem.preferredForwardBufferDuration = 20

    // Create player
    let newPlayer = AVPlayer(playerItem: playerItem)
    newPlayer.automaticallyWaitsToMinimizeStalling = false

    // Set up observations
    setupPlayerObservations(for: newPlayer)

    // Update UI
    player = newPlayer
    duration = try await asset.load(.duration).seconds

    // Start playback
    newPlayer.play()
    isPlaying = true
  }

  private func setupPlayerObservations(for player: AVPlayer) {
    // Time observation
    let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      Task { @MainActor in
        guard let self = self, !self.isSeekingActive else { return }
        self.currentTime = time.seconds
      }
    }

    // Player item observations
    if let playerItem = player.currentItem {
      // Status observation
      playerItem.publisher(for: \.status)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] status in
          switch status {
          case .failed:
            self?.error = playerItem.error
            self?.isLoading = false
          case .readyToPlay:
            self?.isLoading = false
          default:
            break
          }
        }
        .store(in: &playerObservations)

      // Buffer progress observation
      playerItem.publisher(for: \.loadedTimeRanges)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] timeRanges in
          guard let self = self,
            let timeRange = timeRanges.first?.timeRangeValue
          else { return }

          let bufferedEnd = timeRange.start.seconds + timeRange.duration.seconds
          let bufferedAhead = bufferedEnd - self.currentTime
          self.bufferProgress = max(0, bufferedAhead)
        }
        .store(in: &playerObservations)
    }

    // Time control status observation
    player.publisher(for: \.timeControlStatus)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        self?.isPlaying = (status == .playing)
      }
      .store(in: &playerObservations)
  }

  private func scheduleControlsHide() {
    cancelControlsHide()

    controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) {
      [weak self] _ in
      Task { @MainActor in
        withAnimation(.easeInOut(duration: 0.3)) {
          self?.showControls = false
        }
      }
    }
  }

  private func cancelControlsHide() {
    controlsHideTimer?.invalidate()
    controlsHideTimer = nil
  }

  private func cleanup() {
    // Remove time observer
    if let timeObserver = timeObserver, let player = player {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil

    // Cancel all observations
    playerObservations.removeAll()

    // Cancel timers
    cancelControlsHide()

    // Clean up player
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil

    // Reset state
    isPlaying = false
    isLoading = false
    currentTime = 0
    duration = 0
    bufferProgress = 0
    error = nil
  }
}

// MARK: - Computed Properties

extension VRPlayerViewModel {
  /// Formatted current time string
  var formattedCurrentTime: String {
    return formatTime(currentTime)
  }

  /// Formatted duration string
  var formattedDuration: String {
    return formatTime(duration)
  }

  /// Formatted remaining time string
  var formattedRemainingTime: String {
    let remaining = duration - currentTime
    return "-\(formatTime(remaining))"
  }

  /// Progress percentage (0.0 to 1.0)
  var progress: Double {
    guard duration > 0 else { return 0 }
    return currentTime / duration
  }

  /// Buffer percentage (0.0 to 1.0)
  var bufferPercentage: Double {
    guard duration > 0 else { return 0 }
    return min(1.0, bufferProgress / duration)
  }

  /// Whether controls should be shown automatically
  var shouldShowControls: Bool {
    return showControls || showAdjustmentPanel || showSpatialControls || isLoading || error != nil
  }

  private func formatTime(_ time: TimeInterval) -> String {
    let hours = Int(time) / 3600
    let minutes = (Int(time) % 3600) / 60
    let seconds = Int(time) % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%02d:%02d", minutes, seconds)
    }
  }
}

// MARK: - Settings Management

extension VRPlayerViewModel {
  /// Saves current settings as a preset
  func saveSettingsPreset(name: String) {
    // Implementation for saving custom presets
    // This could be stored in UserDefaults or Core Data
    let preset = SettingsPreset(
      name: name,
      videoAdjustments: videoAdjustments,
      spatialSettings: spatialSettings
    )

    // Save to persistent storage
    savePreset(preset)
  }

  /// Loads a settings preset
  func loadSettingsPreset(name: String) {
    // Implementation for loading custom presets
    if let preset = loadPreset(name: name) {
      videoAdjustments = preset.videoAdjustments
      spatialSettings = preset.spatialSettings
      objectWillChange.send()
    }
  }

  private func savePreset(_ preset: SettingsPreset) {
    // Save to UserDefaults or other persistent storage
    if let data = try? JSONEncoder().encode(preset) {
      UserDefaults.standard.set(data, forKey: "VRPlayerPreset_\(preset.name)")
    }
  }

  private func loadPreset(name: String) -> SettingsPreset? {
    guard let data = UserDefaults.standard.data(forKey: "VRPlayerPreset_\(name)"),
      let preset = try? JSONDecoder().decode(SettingsPreset.self, from: data)
    else {
      return nil
    }
    return preset
  }
}

// MARK: - Supporting Types

struct SettingsPreset: Codable {
  let name: String
  let videoAdjustments: VideoAdjustments
  let spatialSettings: SpatialSettings
}
