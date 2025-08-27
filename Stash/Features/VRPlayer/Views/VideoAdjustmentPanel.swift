import SwiftUI

struct VideoAdjustmentPanel: View {
  @Binding var adjustments: VideoAdjustments
  let onPresetSelected: (VideoAdjustments) -> Void
  let onReset: () -> Void

  @State private var showPresets = false

  var body: some View {
    VStack(spacing: 16) {
      // Header
      header

      // Adjustment controls
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          // Basic adjustments
          VStack(spacing: 12) {
            Text("Basic")
              .font(.caption)
              .foregroundColor(.secondary)

            adjustmentSlider(
              title: "Brightness",
              value: $adjustments.brightness,
              range: -100...100,
              format: "%+.0f%%"
            )

            adjustmentSlider(
              title: "Contrast",
              value: $adjustments.contrast,
              range: -100...100,
              format: "%+.0f%%"
            )

            adjustmentSlider(
              title: "Saturation",
              value: $adjustments.saturation,
              range: -100...100,
              format: "%+.0f%%"
            )
          }
          .frame(width: 200)

          Divider()
            .frame(height: 120)

          // Advanced adjustments
          VStack(spacing: 12) {
            Text("Advanced")
              .font(.caption)
              .foregroundColor(.secondary)

            adjustmentSlider(
              title: "Sharpness",
              value: $adjustments.sharpness,
              range: 0...200,
              format: "%.0f%%"
            )

            adjustmentSlider(
              title: "Color Temp",
              value: $adjustments.colorTemperature,
              range: -100...100,
              format: "%+.0f%%"
            )

            adjustmentSlider(
              title: "Gamma",
              value: $adjustments.gamma,
              range: 0.5...2.0,
              format: "%.2f"
            )
          }
          .frame(width: 200)

          Divider()
            .frame(height: 120)

          // Color adjustments
          VStack(spacing: 12) {
            Text("Color")
              .font(.caption)
              .foregroundColor(.secondary)

            adjustmentSlider(
              title: "Hue",
              value: $adjustments.hue,
              range: -180...180,
              format: "%+.0f°"
            )

            adjustmentSlider(
              title: "Vibrance",
              value: $adjustments.vibrance,
              range: -100...100,
              format: "%+.0f%%"
            )
          }
          .frame(width: 200)
        }
        .padding(.horizontal)
      }
      .frame(height: 140)

      // Presets and controls
      bottomControls
    }
    .padding()
    .background(Material.ultraThinMaterial)
    .cornerRadius(16)
    .padding(.horizontal)
    .onChange(of: adjustments) {
      var validated = adjustments
      validated.validate()
      if validated != adjustments {
        adjustments = validated
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Video Adjustments")
          .font(.headline)
          .foregroundColor(.white)

        if adjustments.hasAdjustments {
          Text(adjustments.summary)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else {
          Text("No adjustments applied")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      // Quick reset button
      Button(action: onReset) {
        Image(systemName: "arrow.counterclockwise")
          .font(.title3)
          .foregroundColor(.white)
      }
      .buttonStyle(.plain)
      .disabled(!adjustments.hasAdjustments)
      .opacity(adjustments.hasAdjustments ? 1.0 : 0.5)
    }
  }

  // MARK: - Bottom Controls

  private var bottomControls: some View {
    HStack(spacing: 16) {
      // Preset selector
      Menu {
        ForEach(VideoAdjustments.allPresets.sorted { $0.key < $1.key }, id: \.key) {
          name, preset in
          Button(name) {
            withAnimation(.easeInOut(duration: 0.3)) {
              adjustments = preset
              onPresetSelected(preset)
            }
          }
        }
      } label: {
        HStack {
          Image(systemName: "memories")
          Text("Presets")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.7))
        .cornerRadius(12)
      }
      .foregroundColor(.white)

      Spacer()

      // Value indicators
      HStack(spacing: 12) {
        if abs(adjustments.brightness) > 1 {
          adjustmentBadge("Brightness", adjustments.brightness, format: "%+.0f%%")
        }

        if abs(adjustments.contrast) > 1 {
          adjustmentBadge("Contrast", adjustments.contrast, format: "%+.0f%%")
        }

        if abs(adjustments.saturation) > 1 {
          adjustmentBadge("Saturation", adjustments.saturation, format: "%+.0f%%")
        }

        if abs(adjustments.sharpness - 100) > 1 {
          adjustmentBadge("Sharpness", adjustments.sharpness, format: "%.0f%%")
        }
      }
    }
  }

  // MARK: - Helper Views

  private func adjustmentSlider(
    title: String,
    value: Binding<Float>,
    range: ClosedRange<Float>,
    format: String
  ) -> some View {
    VStack(spacing: 6) {
      HStack {
        Text(title)
          .font(.caption)
          .foregroundColor(.white)

        Spacer()

        Text(String(format: format, value.wrappedValue))
          .font(.caption)
          .foregroundColor(.secondary)
          .monospacedDigit()
      }

      Slider(value: value, in: range) {
        Text(title)
      } minimumValueLabel: {
        Text(String(format: format, range.lowerBound))
          .font(.caption2)
          .foregroundColor(.secondary)
      } maximumValueLabel: {
        Text(String(format: format, range.upperBound))
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .tint(.white)
    }
  }

  private func adjustmentBadge(_ title: String, _ value: Float, format: String) -> some View {
    VStack(spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundColor(.secondary)

      Text(String(format: format, value))
        .font(.caption)
        .foregroundColor(.white)
        .monospacedDigit()
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.black.opacity(0.3))
    .cornerRadius(6)
  }
}

// MARK: - Preview

struct VideoAdjustmentPanel_Previews: PreviewProvider {
  static var previews: some View {
    VideoAdjustmentPanel(
      adjustments: .constant(VideoAdjustments.vivid),
      onPresetSelected: { _ in },
      onReset: {}
    )
    .background(.black)
  }
}
