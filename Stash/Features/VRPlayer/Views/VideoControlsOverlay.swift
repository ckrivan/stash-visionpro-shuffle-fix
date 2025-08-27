import SwiftUI

struct VRVideoControlsOverlay: View {
  @ObservedObject var viewModel: VRPlayerViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 16) {
      // Progress and time info
      progressSection

      // Main control buttons
      controlButtons

      // Secondary controls
      secondaryControls
    }
    .padding()
    .background(
      LinearGradient(
        gradient: Gradient(colors: [
          .black.opacity(0.8),
          .black.opacity(0.6),
          .clear
        ]),
        startPoint: .bottom,
        endPoint: .top
      )
    )
    .cornerRadius(16, corners: [.topLeft, .topRight])
  }

  // MARK: - Progress Section

  private var progressSection: some View {
    VStack(spacing: 8) {
      // Video scrubber
      VideoScrubber(
        currentTime: $viewModel.currentTime,
        duration: viewModel.duration,
        bufferProgress: viewModel.bufferProgress,
        isSeekingActive: viewModel.isSeekingActive
      ) { time in
        viewModel.seek(to: time)
      }

      // Time labels
      HStack {
        Text(viewModel.formattedCurrentTime)
          .font(.caption)
          .foregroundColor(.white)

        Spacer()

        if viewModel.bufferProgress > 0 {
          Text("Buffer: +\(Int(viewModel.bufferProgress))s")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        Spacer()

        Text(viewModel.formattedRemainingTime)
          .font(.caption)
          .foregroundColor(.white)
      }
    }
  }

  // MARK: - Control Buttons

  private var controlButtons: some View {
    HStack(spacing: 24) {
      // Exit button
      Button(action: {
        dismiss()
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .foregroundColor(.white)
      }
      .buttonStyle(.plain)

      // Skip backward
      Button(action: {
        viewModel.skipBackward()
      }) {
        VStack(spacing: 2) {
          Image(systemName: "gobackward.30")
            .font(.title2)
          Text("30s")
            .font(.caption2)
        }
        .foregroundColor(.white)
      }
      .buttonStyle(.plain)

      Spacer()

      // Play/Pause
      Button(action: {
        viewModel.togglePlayPause()
      }) {
        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 50))
          .foregroundColor(.white)
      }
      .buttonStyle(.plain)
      .scaleEffect(viewModel.isPlaying ? 1.0 : 1.1)
      .animation(.easeInOut(duration: 0.2), value: viewModel.isPlaying)

      Spacer()

      // Skip forward
      Button(action: {
        viewModel.skipForward()
      }) {
        VStack(spacing: 2) {
          Image(systemName: "goforward.60")
            .font(.title2)
          Text("60s")
            .font(.caption2)
        }
        .foregroundColor(.white)
      }
      .buttonStyle(.plain)

      // Format toggle
      Button(action: {
        toggleVideoFormat()
      }) {
        VStack(spacing: 2) {
          Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            .font(.title2)
          Text(viewModel.videoFormat.displayName)
            .font(.caption2)
            .lineLimit(1)
        }
        .foregroundColor(.white)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Secondary Controls

  private var secondaryControls: some View {
    HStack(spacing: 16) {
      // Playback speed
      Menu {
        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
          Button("\(speed, specifier: "%.2g")x") {
            viewModel.setPlaybackRate(Float(speed))
          }
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "speedometer")
          Text("\(viewModel.playbackRate, specifier: "%.2g")x")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Material.ultraThinMaterial)
        .cornerRadius(8)
      }
      .foregroundColor(.white)

      // Quality selector
      Menu {
        ForEach(VideoQuality.allCases, id: \.self) { quality in
          Button(quality.displayName) {
            if viewModel.selectedQuality != quality {
              viewModel.selectedQuality = quality
              // Reload video with new quality
              if let video = viewModel.currentVideo {
                Task {
                  await viewModel.loadVideo(video)
                }
              }
            }
          }
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "tv")
          Text(viewModel.selectedQuality.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Material.ultraThinMaterial)
        .cornerRadius(8)
      }
      .foregroundColor(.white)

      Spacer()

      // Random video button
      Button(action: {
        Task {
          await viewModel.loadRandomVideo()
        }
      }) {
        HStack(spacing: 4) {
          Image(systemName: "shuffle")
          Text("Random")
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.purple.opacity(0.7))
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
      .foregroundColor(.white)

      // Adjustment panel toggle
      Button(action: {
        withAnimation(.easeInOut(duration: 0.3)) {
          viewModel.showAdjustmentPanel.toggle()
          if viewModel.showAdjustmentPanel {
            viewModel.showSpatialControls = false
          }
        }
      }) {
        HStack(spacing: 4) {
          Image(systemName: "slider.horizontal.3")
          Text("Adjust")
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(viewModel.showAdjustmentPanel ? Color.blue.opacity(0.7) : Color.clear)
        .background(Material.ultraThinMaterial.opacity(viewModel.showAdjustmentPanel ? 0.0 : 1.0))
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
      .foregroundColor(.white)

      // Spatial controls toggle
      Button(action: {
        withAnimation(.easeInOut(duration: 0.3)) {
          viewModel.showSpatialControls.toggle()
          if viewModel.showSpatialControls {
            viewModel.showAdjustmentPanel = false
          }
        }
      }) {
        HStack(spacing: 4) {
          Image(systemName: "move.3d")
          Text("Spatial")
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(viewModel.showSpatialControls ? Color.green.opacity(0.7) : Color.clear)
        .background(Material.ultraThinMaterial.opacity(viewModel.showSpatialControls ? 0.0 : 1.0))
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
      .foregroundColor(.white)
    }
  }

  // MARK: - Helper Methods

  private func toggleVideoFormat() {
    let newFormat: XBVRVideo.StereoMode

    switch viewModel.videoFormat {
    case .mono:
      newFormat = .sideBySide
    case .sideBySide:
      newFormat = .overUnder
    case .overUnder:
      newFormat = .sideBySide
    }

    withAnimation(.easeInOut(duration: 0.2)) {
      viewModel.updateVideoFormat(newFormat)
    }
  }
}

// MARK: - Video Scrubber

struct VideoScrubber: View {
  @Binding var currentTime: TimeInterval
  let duration: TimeInterval
  let bufferProgress: Double
  let isSeekingActive: Bool
  let onSeek: (TimeInterval) -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Track background
        RoundedRectangle(cornerRadius: 3)
          .fill(.white.opacity(0.3))
          .frame(height: 6)

        // Buffer progress
        RoundedRectangle(cornerRadius: 3)
          .fill(.white.opacity(0.5))
          .frame(
            width: geometry.size.width * CGFloat(bufferProgress / max(duration, 1)),
            height: 6
          )

        // Playback progress
        RoundedRectangle(cornerRadius: 3)
          .fill(.white)
          .frame(
            width: geometry.size.width * CGFloat(currentTime / max(duration, 1)),
            height: 6
          )

        // Thumb
        Circle()
          .fill(.white)
          .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
          .offset(x: thumbPosition(in: geometry) - (isDragging ? 10 : 8))
          .animation(.easeInOut(duration: 0.2), value: isDragging)

        // Invisible touch area
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                if !isDragging {
                  isDragging = true
                }

                let progress = value.location.x / geometry.size.width
                let clampedProgress = max(0, min(1, progress))
                let newTime = duration * clampedProgress

                currentTime = newTime
              }
              .onEnded { _ in
                isDragging = false
                onSeek(currentTime)
              }
          )
      }
    }
    .frame(height: 32)
  }

  private func thumbPosition(in geometry: GeometryProxy) -> CGFloat {
    let progress = currentTime / max(duration, 1)
    return geometry.size.width * CGFloat(progress)
  }
}

// MARK: - Extension for Corner Radius

extension View {
  func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
    clipShape(RoundedCorner(radius: radius, corners: corners))
  }
}

struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius)
    )
    return Path(path.cgPath)
  }
}

// MARK: - Preview

struct VRVideoControlsOverlay_Previews: PreviewProvider {
  static var previews: some View {
    VRVideoControlsOverlay(viewModel: VRPlayerViewModel())
      .background(.black)
  }
}
