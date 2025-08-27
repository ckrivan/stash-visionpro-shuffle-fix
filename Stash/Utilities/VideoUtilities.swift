import Foundation

struct VideoUtilities {
  /// Convert video dimensions to standard resolution labels
  /// - Parameters:
  ///   - width: Video width in pixels
  ///   - height: Video height in pixels
  /// - Returns: Human-readable resolution label (e.g., "240p", "1080p", "4K")
  static func getResolutionLabel(width: Int?, height: Int?) -> String {
    guard let height = height, height > 0 else {
      return "Unknown"
    }

    // Use the standard height-based resolution naming
    switch height {
    case 0..<240:
      return "\(height)p"  // For very low resolutions
    case 240..<360:
      return "240p"
    case 360..<480:
      return "360p"
    case 480..<720:
      return "480p"
    case 720..<1080:
      return "720p"
    case 1080..<1440:
      return "1080p"
    case 1440..<2160:
      return "1440p"
    case 2160..<4320:
      return "4K"
    case 4320...:
      return "8K"
    default:
      return "Unknown"
    }
  }

  /// Get resolution label for a scene file
  /// - Parameter file: StashScene.SceneFile object containing video dimensions
  /// - Returns: Resolution label string
  static func getResolutionLabel(for file: StashScene.SceneFile?) -> String {
    guard let file = file else {
      return "Unknown"
    }

    return getResolutionLabel(width: file.width, height: file.height)
  }

  /// Get the highest resolution label for multiple files
  /// - Parameter files: Array of StashScene.SceneFile objects
  /// - Returns: Resolution label string for the highest resolution file
  static func getHighestResolutionLabel(for files: [StashScene.SceneFile]?) -> String {
    guard let files = files, !files.isEmpty else {
      return "Unknown"
    }

    // Find the file with the highest resolution (based on height)
    if let highestResFile = files.max(by: { a, b -> Bool in
      return (a.height ?? 0) < (b.height ?? 0)
    }) {
      return getResolutionLabel(for: highestResFile)
    }

    return "Unknown"
  }
}
