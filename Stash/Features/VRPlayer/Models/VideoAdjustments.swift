import Foundation
import simd

/// Model for video adjustment settings
struct VideoAdjustments: Codable, Equatable {
  /// Brightness adjustment: -100% to +100% (default: 0%)
  var brightness: Float = 0.0

  /// Contrast adjustment: -100% to +100% (default: 0%)
  var contrast: Float = 0.0

  /// Saturation adjustment: -100% to +100% (default: 0%)
  var saturation: Float = 0.0

  /// Sharpness adjustment: 0% to +200% (default: 100%)
  var sharpness: Float = 100.0

  /// Color temperature adjustment: -100% (warmer) to +100% (cooler) (default: 0%)
  var colorTemperature: Float = 0.0

  /// Gamma adjustment: 0.5 to 2.0 (default: 1.0)
  var gamma: Float = 1.0

  /// Hue shift: -180° to +180° (default: 0°)
  var hue: Float = 0.0

  /// Vibrance adjustment: -100% to +100% (default: 0%)
  var vibrance: Float = 0.0

  // MARK: - Validation

  /// Validates and clamps all values to their acceptable ranges
  mutating func validate() {
    brightness = clamp(brightness, min: -100.0, max: 100.0)
    contrast = clamp(contrast, min: -100.0, max: 100.0)
    saturation = clamp(saturation, min: -100.0, max: 100.0)
    sharpness = clamp(sharpness, min: 0.0, max: 200.0)
    colorTemperature = clamp(colorTemperature, min: -100.0, max: 100.0)
    gamma = clamp(gamma, min: 0.5, max: 2.0)
    hue = clamp(hue, min: -180.0, max: 180.0)
    vibrance = clamp(vibrance, min: -100.0, max: 100.0)
  }

  // MARK: - Presets

  /// Default settings with no adjustments
  static let `default` = VideoAdjustments()

  /// Vivid preset with enhanced colors
  static let vivid = VideoAdjustments(
    brightness: 5.0,
    contrast: 15.0,
    saturation: 20.0,
    sharpness: 120.0,
    vibrance: 15.0
  )

  /// Warm preset for comfortable viewing
  static let warm = VideoAdjustments(
    brightness: 10.0,
    contrast: 5.0,
    saturation: 10.0,
    colorTemperature: -20.0,
    gamma: 0.9
  )

  /// Cool preset for crisp viewing
  static let cool = VideoAdjustments(
    brightness: 0.0,
    contrast: 10.0,
    saturation: 5.0,
    sharpness: 110.0,
    colorTemperature: 15.0,
    gamma: 1.1
  )

  /// Cinema preset for movie-like experience
  static let cinema = VideoAdjustments(
    brightness: -5.0,
    contrast: 20.0,
    saturation: 15.0,
    sharpness: 105.0,
    colorTemperature: -10.0,
    gamma: 1.2
  )

  /// All available presets
  static let allPresets: [String: VideoAdjustments] = [
    "Default": .default,
    "Vivid": .vivid,
    "Warm": .warm,
    "Cool": .cool,
    "Cinema": .cinema
  ]
}

// MARK: - Helper Functions

private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
  return Swift.max(minValue, Swift.min(maxValue, value))
}

// MARK: - Metal Shader Compatible Structure

/// Structure compatible with Metal shaders for GPU processing
struct VideoAdjustmentsUniform {
  var brightness: Float
  var contrast: Float
  var saturation: Float
  var sharpness: Float
  var colorTemp: Float
  var gamma: Float
  var hue: Float
  var vibrance: Float

  init(from adjustments: VideoAdjustments) {
    // Convert percentage values to shader-friendly ranges
    brightness = adjustments.brightness / 100.0  // -1.0 to 1.0
    contrast = 1.0 + (adjustments.contrast / 100.0)  // 0.0 to 2.0
    saturation = 1.0 + (adjustments.saturation / 100.0)  // 0.0 to 2.0
    sharpness = adjustments.sharpness / 100.0  // 0.0 to 2.0
    colorTemp = adjustments.colorTemperature / 100.0  // -1.0 to 1.0
    gamma = adjustments.gamma  // 0.5 to 2.0
    hue = adjustments.hue * Float.pi / 180.0  // Convert degrees to radians
    vibrance = adjustments.vibrance / 100.0  // -1.0 to 1.0
  }
}

// MARK: - Extensions

extension VideoAdjustments {
  /// Returns true if any adjustments are applied (not default values)
  var hasAdjustments: Bool {
    return self != .default
  }

  /// Returns a Metal-compatible uniform structure
  var uniform: VideoAdjustmentsUniform {
    return VideoAdjustmentsUniform(from: self)
  }

  /// Resets all adjustments to default values
  mutating func reset() {
    self = .default
  }

  /// Applies a preset by name
  mutating func applyPreset(named name: String) {
    if let preset = Self.allPresets[name] {
      self = preset
    }
  }

  /// Returns adjustment summary for display
  var summary: String {
    var components: [String] = []

    if brightness != 0 {
      components.append("Brightness: \(brightness > 0 ? "+" : "")\(Int(brightness))%")
    }
    if contrast != 0 {
      components.append("Contrast: \(contrast > 0 ? "+" : "")\(Int(contrast))%")
    }
    if saturation != 0 {
      components.append("Saturation: \(saturation > 0 ? "+" : "")\(Int(saturation))%")
    }
    if sharpness != 100 {
      components.append("Sharpness: \(Int(sharpness))%")
    }
    if colorTemperature != 0 {
      let direction = colorTemperature > 0 ? "Cooler" : "Warmer"
      components.append("\(direction): \(Int(abs(colorTemperature)))%")
    }

    return components.isEmpty ? "No adjustments" : components.joined(separator: ", ")
  }
}
