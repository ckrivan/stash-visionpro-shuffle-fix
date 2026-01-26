import SwiftUI

struct SpatialControlsView: View {
  @Binding var settings: SpatialSettings
  let onPresetSelected: (SpatialSettings) -> Void
  let onReset: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      // Header
      header

      // Control sections
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          // Position controls
          VStack(spacing: 12) {
            Text("Position")
              .font(.caption)
              .foregroundColor(.secondary)

            spatialSlider(
              title: "Distance",
              value: $settings.distance,
              range: 2...10,
              format: "%.1fm"
            )

            spatialSlider(
              title: "Height",
              value: $settings.offsetY,
              range: -2...2,
              format: "%+.1fm"
            )

            spatialSlider(
              title: "Zoom",
              value: $settings.zoom,
              range: 0.5...2.0,
              format: "%.1fx"
            )
          }
          .frame(width: 180)

          Divider()
            .frame(height: 120)

          // Rotation controls
          VStack(spacing: 12) {
            Text("Rotation")
              .font(.caption)
              .foregroundColor(.secondary)

            spatialSlider(
              title: "Horizontal",
              value: $settings.rotationY,
              range: -180...180,
              format: "%+.0f°"
            )

            spatialSlider(
              title: "Vertical",
              value: $settings.rotationX,
              range: -90...90,
              format: "%+.0f°"
            )

            spatialSlider(
              title: "Roll",
              value: $settings.rotationZ,
              range: -180...180,
              format: "%+.0f°"
            )
          }
          .frame(width: 180)

          Divider()
            .frame(height: 120)

          // Tilt controls
          VStack(spacing: 12) {
            Text("Tilt")
              .font(.caption)
              .foregroundColor(.secondary)

            spatialSlider(
              title: "Tilt X",
              value: $settings.tiltX,
              range: -45...45,
              format: "%+.0f°"
            )

            spatialSlider(
              title: "Tilt Y",
              value: $settings.tiltY,
              range: -45...45,
              format: "%+.0f°"
            )

            spatialSlider(
              title: "Tilt Z",
              value: $settings.tiltZ,
              range: -45...45,
              format: "%+.0f°"
            )
          }
          .frame(width: 180)

          Divider()
            .frame(height: 120)

          // View settings
          VStack(spacing: 12) {
            Text("View")
              .font(.caption)
              .foregroundColor(.secondary)

            spatialSlider(
              title: "Field of View",
              value: $settings.fieldOfView,
              range: 120...180,
              format: "%.0f°"
            )

            spatialSlider(
              title: "IPD",
              value: $settings.ipd,
              range: 50...80,
              format: "%.0fmm"
            )

            spatialSlider(
              title: "Eye Sep.",
              value: $settings.eyeSeparation,
              range: 0.5...2.0,
              format: "%.1fx"
            )
          }
          .frame(width: 180)
        }
        .padding(.horizontal)
      }
      .frame(height: 140)

      // Bottom controls
      bottomControls
    }
    .padding()
    .background(Material.ultraThinMaterial)
    .cornerRadius(16)
    .padding(.horizontal)
    .onChange(of: settings) { _, newSettings in
      var validated = newSettings
      validated.validate()
      if validated != newSettings {
        settings = validated
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Spatial Controls")
          .font(.headline)
          .foregroundColor(.white)

        if settings.hasModifications {
          Text(settings.summary)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else {
          Text("Default spatial positioning")
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
      .disabled(!settings.hasModifications)
      .opacity(settings.hasModifications ? 1.0 : 0.5)
    }
  }

  // MARK: - Bottom Controls

  private var bottomControls: some View {
    HStack(spacing: 16) {
      // Preset selector
      Menu {
        ForEach(SpatialSettings.allPresets.sorted { $0.key < $1.key }, id: \.key) {
          name, preset in
          Button(name) {
            withAnimation(.easeInOut(duration: 0.5)) {
              settings = preset
              onPresetSelected(preset)
            }
          }
        }
      } label: {
        HStack {
          Image(systemName: "cube")
          Text("Presets")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.green.opacity(0.7))
        .cornerRadius(12)
      }
      .foregroundColor(.white)

      // Quick position buttons
      HStack(spacing: 8) {
        quickPositionButton("Center", centerView)
        quickPositionButton("Recenter", recenterView)
        quickPositionButton("Comfort", comfortView)
      }

      Spacer()

      // Current values display
      HStack(spacing: 12) {
        if abs(settings.distance - 6.0) > 0.1 {
          spatialBadge("Distance", settings.distance, format: "%.1fm")
        }

        if abs(settings.zoom - 1.0) > 0.1 {
          spatialBadge("Zoom", settings.zoom, format: "%.1fx")
        }

        if abs(settings.rotationY) > 1 {
          spatialBadge("Rotation", settings.rotationY, format: "%+.0f°")
        }
      }
    }
  }

  // MARK: - Helper Views

  private func spatialSlider(
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
      .tint(.green)
    }
  }

  private func spatialBadge(_ title: String, _ value: Float, format: String) -> some View {
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

  private func quickPositionButton(_ title: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.5))
        .cornerRadius(8)
    }
    .buttonStyle(.plain)
    .foregroundColor(.white)
  }

  // MARK: - Quick Actions

  private func centerView() {
    withAnimation(.easeInOut(duration: 0.5)) {
      settings.rotationX = 0
      settings.rotationY = 0
      settings.rotationZ = 0
      settings.offsetX = 0
      settings.offsetZ = 0
    }
  }

  private func recenterView() {
    withAnimation(.easeInOut(duration: 0.5)) {
      settings = .default
      onPresetSelected(settings)
    }
  }

  private func comfortView() {
    withAnimation(.easeInOut(duration: 0.5)) {
      settings = .comfort
      onPresetSelected(settings)
    }
  }
}

// MARK: - 3D Position Visualizer (Optional)

struct PositionVisualizer: View {
  let settings: SpatialSettings

  var body: some View {
    VStack(spacing: 8) {
      Text("Position Preview")
        .font(.caption)
        .foregroundColor(.secondary)

      ZStack {
        // Background grid
        Grid {
          ForEach(0..<3, id: \.self) { _ in
            GridRow {
              ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                  .fill(.clear)
                  .frame(width: 20, height: 20)
                  .border(.secondary.opacity(0.3))
              }
            }
          }
        }

        // Position indicator
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
          .offset(
            x: CGFloat(settings.offsetX * 20),  // Scale for visualization
            y: CGFloat(settings.offsetY * 20)
          )
      }
      .frame(width: 60, height: 60)
    }
  }
}

// MARK: - Preview

struct SpatialControlsView_Previews: PreviewProvider {
  static var previews: some View {
    SpatialControlsView(
      settings: .constant(SpatialSettings.immersive),
      onPresetSelected: { _ in },
      onReset: {}
    )
    .background(.black)
  }
}
