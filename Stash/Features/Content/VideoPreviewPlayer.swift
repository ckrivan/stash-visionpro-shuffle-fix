import AVKit
import SwiftUI

extension AVPlayer {
  var isPlaying: Bool {
    return rate != 0 && error == nil
  }
}

// Using GlobalVideoManager from PreviewPlayerManager.swift
// This class is now deprecated but keeping for compatibility
@available(*, deprecated, renamed: "GlobalVideoManager")
class LocalPreviewManager: ObservableObject {
  static let shared = LocalPreviewManager()
  private init() {}
  var players: [AVPlayer] = []

  func muteAll() {
    GlobalVideoManager.shared.muteAll()
  }

  func stopAllPreviews() {
    GlobalVideoManager.shared.stopAllPreviews()
  }

  func registerPlayer(_ player: AVPlayer) {
    GlobalVideoManager.shared.registerPlayer(player)
  }

  func unregisterPlayer(_ player: AVPlayer) {
    GlobalVideoManager.shared.unregisterPlayer(player)
  }
}

struct VideoPreviewPlayer: View {
  let previewURL: URL
  let streamURL: URL
  // Removed fixed duration to allow continuous playback

  @State private var player: AVPlayer?
  @State private var isFullScreen = false
  @State private var previewTime: CMTime?

  var body: some View {
    VStack(spacing: 8) {
      VideoPlayer(player: player)
        .controlSize(.mini)
        .aspectRatio(16 / 9, contentMode: ContentMode.fill)
        .frame(minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Use overlay to prevent the controls from appearing
        .allowsHitTesting(false)
        .overlay(
          Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        )
        .onAppear {
          // Only initialize the player but don't start playback
          Task {
            await setupPlayerWithoutAutoplay()
          }
          if let player = player {
            GlobalVideoManager.shared.registerPlayer(player)
          }
        }
        .onDisappear {
          cleanup()
        }
        // Add a tap gesture to start playback when tapped
        .onTapGesture {
          if let player = player, !player.isPlaying {
            // Start playing
            GlobalVideoManager.shared.stopAllPreviews()  // Stop other players first

            if let previewTime = previewTime {
              player.seek(to: previewTime)
              player.isMuted = true  // Ensure muted
              player.play()
            }
          } else {
            // When pausing, completely stop the player
            // This is the key fix to prevent muted audio from continuing
            cleanup()

            // Recreate the player in stopped state
            Task {
              await setupPlayerWithoutAutoplay()
            }
          }
        }
        // Add long press gesture for full screen
        .onLongPressGesture {
          isFullScreen = true
        }

        .fullScreenCover(isPresented: $isFullScreen) {
          VideoPlayerView(
            scene: StashScene(
              id: "preview",
              title: "Preview",
              details: nil,
              url: nil,
              date: nil,
              rating100: nil,
              organized: false,
              oCounter: 0,
              paths: StashScene.ScenePaths(
                screenshot: "",
                preview: "",
                stream: streamURL.absoluteString,
                webp: nil,
                vtt: nil,
                sprite: nil,
                funscript: nil,
                interactive_heatmap: nil
              ),
              files: nil,
              performers: nil,
              tags: nil,
              studio: nil,
              stashIds: nil,
              createdAt: nil,
              updatedAt: nil
            )
          )
        }
    }
  }

  private func setupPlayerWithoutAutoplay() async {
    // Create an AVPlayerItem with HLS asset
    let asset = AVURLAsset(url: previewURL)
    let playerItem = AVPlayerItem(asset: asset)

    await MainActor.run {
      player = AVPlayer(playerItem: playerItem)
      player?.isMuted = true  // Always enforce muting for previews

      // Add loop observer to continuously play
      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: playerItem,
        queue: .main
      ) { [weak player] _ in
        player?.seek(to: .zero)
        player?.play()  // Continue playing when reaching the end
      }
    }

    do {
      let duration = try await asset.load(.duration)
      let totalSeconds = CMTimeGetSeconds(duration)
      if totalSeconds > 0 {
        // Start at a random position but allow complete playback
        let randomStart = Double.random(in: 0...(totalSeconds * 0.7))
        let seekTime = CMTime(seconds: randomStart, preferredTimescale: 1)

        await MainActor.run {
          previewTime = seekTime
          player?.seek(to: seekTime)
          // Don't automatically play - wait for user tap
        }
      }
    } catch {
      print("Error loading video duration: \(error)")
    }
  }

  // Keep this for backward compatibility with any existing code
  private func setupPreviewPlayer() async {
    await setupPlayerWithoutAutoplay()
  }

  private func cleanup() {
    if let player = player {
      // First pause and ensure volume is zero
      player.pause()
      player.volume = 0
      player.isMuted = true

      // Remove any observers
      NotificationCenter.default.removeObserver(self)

      // Multiple item replacements to ensure audio stops completely
      player.replaceCurrentItem(with: nil)

      // This dummy replacement trick helps flush audio buffers
      let dummy = AVPlayerItem(url: URL(string: "about:blank")!)
      player.replaceCurrentItem(with: dummy)
      player.replaceCurrentItem(with: nil)

      // Make sure player is unregistered from global manager
      GlobalVideoManager.shared.unregisterPlayer(player)

      print("🔇 Preview player completely stopped and cleaned up")
    }

    // Set player reference to nil to release memory
    player = nil
  }
}
