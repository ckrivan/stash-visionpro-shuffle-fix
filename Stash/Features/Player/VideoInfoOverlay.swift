import SwiftUI

/// A view that displays technical details about a video in the full-screen player
struct VideoInfoOverlay: View {
  let scene: StashScene
  let isVisible: Bool

  var body: some View {
    VStack(alignment: .trailing) {
      Spacer()

      if isVisible, let files = scene.files, !files.isEmpty {
        HStack {
          Spacer()

          VStack(alignment: .leading, spacing: 8) {
            // Title and resolution
            HStack(alignment: .center) {
              Text("Technical Details")
                .font(.headline)
                .foregroundStyle(.white)

              Text("•")
                .foregroundStyle(.secondary)

              Text(VideoUtilities.getHighestResolutionLabel(for: files))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            }

            Divider()
              .background(Color.white.opacity(0.3))

            // Technical details - first file only
            if let file = files.first {
              Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                // Dimensions
                if let width = file.width, let height = file.height {
                  GridRow {
                    Text("Dimensions:")
                      .foregroundStyle(.secondary)
                    Text("\(width) × \(height)")
                      .foregroundStyle(.white)
                  }
                }

                // File size
                GridRow {
                  Text("Size:")
                    .foregroundStyle(.secondary)
                  Text(file.formattedSize)
                    .foregroundStyle(.white)
                }

                // Codecs
                if let videoCodec = file.video_codec {
                  GridRow {
                    Text("Video Codec:")
                      .foregroundStyle(.secondary)
                    Text(videoCodec)
                      .foregroundStyle(.white)
                  }
                }

                if let audioCodec = file.audio_codec {
                  GridRow {
                    Text("Audio Codec:")
                      .foregroundStyle(.secondary)
                    Text(audioCodec)
                      .foregroundStyle(.white)
                  }
                }

                // Frame rate
                if let framerate = file.framerate {
                  GridRow {
                    Text("Frame Rate:")
                      .foregroundStyle(.secondary)
                    Text("\(Int(framerate)) fps")
                      .foregroundStyle(.white)
                  }
                }

                // Bitrate
                if let bitrate = file.bitrate {
                  GridRow {
                    Text("Bitrate:")
                      .foregroundStyle(.secondary)
                    let mbps = Double(bitrate) / 1000.0
                    Text(String(format: "%.2f Mbps", mbps))
                      .foregroundStyle(.white)
                  }
                }

                // Duration
                if let duration = file.duration {
                  GridRow {
                    Text("Duration:")
                      .foregroundStyle(.secondary)
                    Text(formatDuration(duration))
                      .foregroundStyle(.white)
                  }
                }
              }
              .font(.callout)
            }
          }
          .padding(16)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.black.opacity(0.7))
          )
          .padding(.horizontal, 20)
          .padding(.bottom, 100)  // Add bottom padding to avoid overlap with player controls
        }
        .transition(.opacity)
      }
    }
  }

  /// Format duration in seconds to a human-readable string (HH:MM:SS)
  private func formatDuration(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
    }
  }
}

#Preview {
  ZStack {
    // Dark background to simulate video player
    Color.black.ignoresSafeArea()

    VideoInfoOverlay(
      scene: StashScene.example,
      isVisible: true
    )
  }
}
