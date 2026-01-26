import Foundation
import simd

/// Model for spatial positioning and viewing settings in VR
struct SpatialSettings: Codable, Equatable {
  // MARK: - Tilt Controls

  /// Tilt on X-axis: -45° to +45° (default: 0°)
  var tiltX: Float = 0.0

  /// Tilt on Y-axis: -45° to +45° (default: 0°)
  var tiltY: Float = 0.0

  /// Tilt on Z-axis: -45° to +45° (default: 0°)
  var tiltZ: Float = 0.0

  // MARK: - Zoom and Distance

  /// Zoom level: 0.5x to 2.0x (default: 1.0x)
  var zoom: Float = 1.0

  /// Viewing distance in meters: 2.0m to 10.0m (default: 6.0m)
  var distance: Float = 6.0

  // MARK: - Rotation

  /// Rotation around Y-axis: -180° to +180° (default: 0°)
  var rotationY: Float = 0.0

  /// Rotation around X-axis: -90° to +90° (default: 0°)
  var rotationX: Float = 0.0

  /// Rotation around Z-axis: -180° to +180° (default: 0°)
  var rotationZ: Float = 0.0

  // MARK: - Position Offset

  /// Horizontal offset: -2.0m to +2.0m (default: 0.0m)
  var offsetX: Float = 0.0

  /// Vertical offset: -2.0m to +2.0m (default: -0.3m for comfortable viewing)
  var offsetY: Float = -0.3

  /// Depth offset: -2.0m to +2.0m (default: 0.0m)
  var offsetZ: Float = 0.0

  // MARK: - Field of View

  /// Horizontal field of view: 120° to 180° (default: 160°)
  var fieldOfView: Float = 160.0

  // MARK: - Eye Settings

  /// Interpupillary distance (IPD): 50mm to 80mm (default: 63mm)
  var ipd: Float = 63.0

  /// Eye separation multiplier for stereo content: 0.5x to 2.0x (default: 1.0x)
  var eyeSeparation: Float = 1.0

  // MARK: - Validation

  /// Validates and clamps all values to their acceptable ranges
  mutating func validate() {
    tiltX = clamp(tiltX, min: -45.0, max: 45.0)
    tiltY = clamp(tiltY, min: -45.0, max: 45.0)
    tiltZ = clamp(tiltZ, min: -45.0, max: 45.0)

    zoom = clamp(zoom, min: 0.5, max: 2.0)
    distance = clamp(distance, min: 2.0, max: 10.0)

    rotationY = clampAngle(rotationY)
    rotationX = clamp(rotationX, min: -90.0, max: 90.0)
    rotationZ = clampAngle(rotationZ)

    offsetX = clamp(offsetX, min: -2.0, max: 2.0)
    offsetY = clamp(offsetY, min: -2.0, max: 2.0)
    offsetZ = clamp(offsetZ, min: -2.0, max: 2.0)

    fieldOfView = clamp(fieldOfView, min: 120.0, max: 180.0)

    ipd = clamp(ipd, min: 50.0, max: 80.0)
    eyeSeparation = clamp(eyeSeparation, min: 0.5, max: 2.0)
  }

  // MARK: - Presets

  /// Default comfortable viewing settings
  static let `default` = SpatialSettings()

  /// Close-up viewing preset
  static let closeUp = SpatialSettings(
    zoom: 1.3,
    distance: 4.0,
    offsetY: -0.1
  )

  /// Immersive wide view preset
  static let immersive = SpatialSettings(
    zoom: 0.8,
    distance: 8.0,
    offsetY: -0.5,
    fieldOfView: 170.0
  )

  /// Cinema-style viewing preset
  static let cinema = SpatialSettings(
    zoom: 1.1,
    distance: 7.0,
    offsetY: -0.2,
    fieldOfView: 140.0
  )

  /// Comfort preset for extended viewing
  static let comfort = SpatialSettings(
    zoom: 0.9,
    distance: 6.5,
    offsetY: -0.4,
    fieldOfView: 150.0
  )

  /// All available presets
  static let allPresets: [String: SpatialSettings] = [
    "Default": .default,
    "Close-up": .closeUp,
    "Immersive": .immersive,
    "Cinema": .cinema,
    "Comfort": .comfort
  ]
}

// MARK: - Helper Functions

private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
  return Swift.max(minValue, Swift.min(maxValue, value))
}

private func clampAngle(_ angle: Float) -> Float {
  var result = angle
  while result > 180.0 { result -= 360.0 }
  while result < -180.0 { result += 360.0 }
  return result
}

// MARK: - Transform Calculations

extension SpatialSettings {
  /// Computes the 3D position for the video surface
  var position: SIMD3<Float> {
    return SIMD3<Float>(offsetX, offsetY, -distance + offsetZ)
  }

  /// Computes the rotation quaternion for the video surface
  var orientation: simd_quatf {
    // Combine all rotations
    let rotX = simd_quatf(angle: rotationX * .pi / 180.0, axis: SIMD3<Float>(1, 0, 0))
    let rotY = simd_quatf(angle: rotationY * .pi / 180.0, axis: SIMD3<Float>(0, 1, 0))
    let rotZ = simd_quatf(angle: rotationZ * .pi / 180.0, axis: SIMD3<Float>(0, 0, 1))

    // Apply tilt
    let tiltXQuat = simd_quatf(angle: tiltX * .pi / 180.0, axis: SIMD3<Float>(1, 0, 0))
    let tiltYQuat = simd_quatf(angle: tiltY * .pi / 180.0, axis: SIMD3<Float>(0, 1, 0))
    let tiltZQuat = simd_quatf(angle: tiltZ * .pi / 180.0, axis: SIMD3<Float>(0, 0, 1))

    // Combine rotations: tilt first, then rotation
    return rotY * rotX * rotZ * tiltY * tiltX * tiltZQuat
  }

  /// Computes the scale factor based on zoom
  var scale: SIMD3<Float> {
    return SIMD3<Float>(repeating: zoom)
  }

  /// Computes the horizontal field of view in radians
  var horizontalFOVRadians: Float {
    return fieldOfView * .pi / 180.0
  }

  /// Computes the IPD in meters
  var ipdMeters: Float {
    return ipd / 1000.0  // Convert mm to meters
  }

  /// Computes the effective eye separation for stereo content
  var effectiveEyeSeparation: Float {
    return ipdMeters * eyeSeparation
  }
}

// MARK: - Extensions

extension SpatialSettings {
  /// Returns true if any settings are modified from default
  var hasModifications: Bool {
    return self != .default
  }

  /// Resets all settings to default values
  mutating func reset() {
    self = .default
  }

  /// Applies a preset by name
  mutating func applyPreset(named name: String) {
    if let preset = Self.allPresets[name] {
      self = preset
    }
  }

  /// Returns settings summary for display
  var summary: String {
    var components: [String] = []

    if zoom != 1.0 {
      components.append("Zoom: \(String(format: "%.1f", zoom))x")
    }
    if distance != 6.0 {
      components.append("Distance: \(String(format: "%.1f", distance))m")
    }
    if rotationY != 0 {
      components.append("Rotation: \(Int(rotationY))°")
    }
    if offsetY != -0.3 {
      components.append("Height: \(String(format: "%.1f", offsetY))m")
    }
    if fieldOfView != 160.0 {
      components.append("FOV: \(Int(fieldOfView))°")
    }

    return components.isEmpty ? "Default view" : components.joined(separator: ", ")
  }

  /// Returns adjustment delta from default for animations
  var deltaFromDefault: SpatialSettings {
    let defaultSettings = SpatialSettings.default
    return SpatialSettings(
      tiltX: tiltX - defaultSettings.tiltX,
      tiltY: tiltY - defaultSettings.tiltY,
      tiltZ: tiltZ - defaultSettings.tiltZ,
      zoom: zoom - defaultSettings.zoom,
      distance: distance - defaultSettings.distance,
      rotationY: rotationY - defaultSettings.rotationY,
      rotationX: rotationX - defaultSettings.rotationX,
      rotationZ: rotationZ - defaultSettings.rotationZ,
      offsetX: offsetX - defaultSettings.offsetX,
      offsetY: offsetY - defaultSettings.offsetY,
      offsetZ: offsetZ - defaultSettings.offsetZ,
      fieldOfView: fieldOfView - defaultSettings.fieldOfView,
      ipd: ipd - defaultSettings.ipd,
      eyeSeparation: eyeSeparation - defaultSettings.eyeSeparation
    )
  }
}
