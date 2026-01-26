import AVKit
import SwiftUI

class GlobalVideoManager: NSObject, ObservableObject {
  static let shared = GlobalVideoManager()

  // Track all active preview players
  private var activePlayers = NSMapTable<AVPlayer, NSNull>.weakToStrongObjects()
  @Published private(set) var isPlaying = false
  // Track if we're currently in a cleanup operation
  private var isCleaningUp = false

  func registerPlayer(_ player: AVPlayer) {
    print("📝 Registering preview player in global manager")
    activePlayers.setObject(NSNull(), forKey: player)
  }

  func unregisterPlayer(_ player: AVPlayer) {
    print("📝 Unregistering preview player from global manager")
    activePlayers.removeObject(forKey: player)
  }

  func muteAll() {
    print("🔇 Muting all preview players")
    enumeratePlayers { player in
      player.isMuted = true
      player.volume = 0
    }
  }

  func stopAllPreviews() {
    // Prevent recursive calls
    if isCleaningUp {
      print("⚠️ Already cleaning up, skipping duplicate call")
      return
    }

    isCleaningUp = true
    print("⏹️ Performing safe audio cleanup")

    // Stop and remove all players safely
    enumeratePlayers { player in
      // First pause and mute
      player.pause()
      player.volume = 0
      player.isMuted = true

      // Remove observers safely
      NotificationCenter.default.removeObserver(
        player, name: .AVPlayerItemDidPlayToEndTime, object: nil)

      // Remove the player item to stop any audio - this is critical
      // This completely destroys the AVPlayerItem which stops all audio processing
      player.replaceCurrentItem(with: nil)

      // Added hack: create and immediately release a dummy item
      // This helps clear any lingering audio buffers
      let dummy = AVPlayerItem(url: URL(string: "about:blank")!)
      player.replaceCurrentItem(with: dummy)
      player.replaceCurrentItem(with: nil)
    }

    // Clear all references in the map table
    activePlayers = NSMapTable<AVPlayer, NSNull>.weakToStrongObjects()

    // Simple audio session reset
    resetAudioSession()

    // Short delay to ensure cleanup completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self else { return }
      self.isCleaningUp = false
      print("✅ Audio cleanup complete")
    }
  }

  private func resetAudioSession() {
    do {
      // Fully deactivate and reactivate the audio session
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

      // Reset to default settings
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: .default, options: [.mixWithOthers, .duckOthers])

      // Activate with new settings
      try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

      print("✅ Audio session reset successfully")
    } catch {
      print("❌ Failed to reset audio session: \(error)")
    }
  }

  private func resetAudioEngine() {
    // Remove this method as it's causing crashes
    // We'll use a safer approach with just AVAudioSession
    print("🔊 Using safer audio session reset instead of audio engine reset")
  }

  func forceStopAllAudio() {
    // The absolute minimum needed to stop duplicate audio

    // Stop all tracked players - just the essentials
    enumeratePlayers { player in
      // The critical part that fixes the issue:
      player.pause()
      player.replaceCurrentItem(with: nil)
    }

    // Clear all references in the map table
    activePlayers = NSMapTable<AVPlayer, NSNull>.weakToStrongObjects()

    // Simple audio reset - just the essential part that solves the problem
    do {
      // The minimal audio session reset that still works
      try AVAudioSession.sharedInstance().setActive(false)

      // One category toggle to reset state - absolutely essential
      try AVAudioSession.sharedInstance().setCategory(.ambient)
      try AVAudioSession.sharedInstance().setActive(true)

      // Back to playback
      try AVAudioSession.sharedInstance().setCategory(.playback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("⚠️ Audio session reset error: \(error)")
    }
  }

  private func enumeratePlayers(action: (AVPlayer) -> Void) {
    guard let players = activePlayers.keyEnumerator().allObjects as? [AVPlayer] else {
      return
    }
    for player in players {
      action(player)
    }
  }
}

class PreviewPlayerManager: NSObject, ObservableObject {
  @Published var player: AVPlayer?
  private var loopObserver: Any?
  private var statusObserver: NSKeyValueObservation?
  @Published private(set) var isPlaying = false

  func startPreview(url: URL) {
    // Stop any existing preview
    stopPreview()

    print("🎬 Starting preview with URL: \(url.absoluteString)")

    // Create request with necessary headers
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.setValue("bytes=0-", forHTTPHeaderField: "Range")  // Request full range
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")

    // Create asset with custom URL request
    let asset = AVURLAsset(
      url: url,
      options: [
        "AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:],
        "AVURLAssetOutOfBandMIMETypeKey": "video/mp4"
      ])

    let playerItem = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: playerItem)

    // Configure player
    player.isMuted = true
    player.actionAtItemEnd = .none
    player.automaticallyWaitsToMinimizeStalling = true

    // Always try to start playing immediately
    player.play()

    // Observe status
    statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        switch item.status {
        case .readyToPlay:
          print("🎬 Preview ready to play")
          self?.isPlaying = true
          player.play()  // Start playing when ready
        case .failed:
          if let error = item.error {
            print("❌ Preview failed to load: \(error)")
            print("❌ Error details: \(String(describing: item.errorLog()))")
          }
          self?.isPlaying = false
        case .unknown:
          print("❌ Preview status unknown")
          self?.isPlaying = false
        @unknown default:
          break
        }
      }
    }

    // Add loop observer
    loopObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak player] _ in
      print("🎬 Preview reached end, looping...")
      player?.seek(to: .zero)
      player?.play()
    }

    // Add error observer
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { notification in
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        print("❌ Preview playback failed: \(error)")
      }
    }

    self.player = player

    // Register with global manager
    GlobalVideoManager.shared.registerPlayer(player)

    print("🎬 Preview player initialized")
  }

  func stopPreview() {
    guard isPlaying else { return }

    print("🎬 Stopping preview")

    // Remove observers
    if let observer = loopObserver {
      NotificationCenter.default.removeObserver(observer)
      loopObserver = nil
    }

    statusObserver?.invalidate()
    statusObserver = nil

    // Unregister from global manager if we have a player
    if let player = player {
      GlobalVideoManager.shared.unregisterPlayer(player)
    }

    // Stop and cleanup player
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    isPlaying = false

    print("🎬 Preview stopped and cleaned up")
  }

  deinit {
    stopPreview()
  }
}
