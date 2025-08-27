import SwiftUI

/// A view that displays technical information about a scene's video files
struct SceneFileInfoView: View {
  let files: [StashScene.SceneFile]?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let files = files, !files.isEmpty {
        // Display resolution and file size on the first row
        HStack(spacing: 12) {
          // Resolution
          Label {
            Text(VideoUtilities.getHighestResolutionLabel(for: files))
              .fontWeight(.medium)
          } icon: {
            Image(systemName: "rectangle.on.rectangle")
              .foregroundStyle(.secondary)
          }

          // File size
          if let file = files.first, let size = file.size {
            Text("•")
              .foregroundStyle(.tertiary)
            Label {
              Text(file.formattedSize)
                .fontWeight(.medium)
            } icon: {
              Image(systemName: "externaldrive")
                .foregroundStyle(.secondary)
            }
          }

          // Duration
          if let file = files.first, let duration = file.duration {
            Text("•")
              .foregroundStyle(.tertiary)
            Label {
              Text(formatDuration(duration))
                .fontWeight(.medium)
            } icon: {
              Image(systemName: "clock")
                .foregroundStyle(.secondary)
            }
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        // Display codec and framerate info on second row
        if let file = files.first {
          HStack(spacing: 12) {
            // Video codec
            if let videoCodec = file.video_codec, !videoCodec.isEmpty {
              Label {
                Text(videoCodec)
                  .fontWeight(.medium)
              } icon: {
                Image(systemName: "film")
                  .foregroundStyle(.secondary)
              }
            }

            // Audio codec
            if let audioCodec = file.audio_codec, !audioCodec.isEmpty {
              Text("•")
                .foregroundStyle(.tertiary)
              Label {
                Text(audioCodec)
                  .fontWeight(.medium)
              } icon: {
                Image(systemName: "speaker.wave.2")
                  .foregroundStyle(.secondary)
              }
            }

            // Framerate
            if let framerate = file.framerate {
              Text("•")
                .foregroundStyle(.tertiary)
              Label {
                Text("\(Int(framerate)) fps")
                  .fontWeight(.medium)
              } icon: {
                Image(systemName: "speedometer")
                  .foregroundStyle(.secondary)
              }
            }
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  /// Format duration in seconds to a human-readable string (HH:MM:SS)
  private func formatDuration(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }
}

#Preview {
  SceneFileInfoView(files: [
    StashScene.SceneFile(
      size: 1_234_567_890,
      duration: 3600,
      video_codec: "h264",
      audio_codec: "aac",
      width: 3840,
      height: 2160,
      framerate: 60,
      bitrate: 10000,
      fingerprints: nil
    )
  ])
  .padding()
  .background(.ultraThinMaterial)
  .cornerRadius(12)
}
