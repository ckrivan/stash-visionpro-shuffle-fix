import CoreGraphics
import Foundation

struct XBVRVideo: Codable, Identifiable, Equatable {
  let id: String
  let title: String
  let duration: TimeInterval
  let resolution: CGSize
  let videoType: VideoType
  let stereoMode: StereoMode
  let streamURL: URL
  let thumbnailURL: URL?
  let tags: [String]?
  let performers: [String]?
  let studio: String?
  let filePath: String?
  let dateAdded: Date?
  let fileSize: Int64?

  enum VideoType: String, Codable, CaseIterable {
    case flat = "flat"
    case vr180 = "vr180"
    case vr360 = "vr360"

    var displayName: String {
      switch self {
      case .flat: return "Flat (2D)"
      case .vr180: return "VR 180°"
      case .vr360: return "VR 360°"
      }
    }
  }

  enum StereoMode: String, Codable, CaseIterable {
    case mono = "mono"
    case sideBySide = "sbs"
    case overUnder = "ou"

    var displayName: String {
      switch self {
      case .mono: return "Mono"
      case .sideBySide: return "Side-by-Side"
      case .overUnder: return "Over-Under"
      }
    }
  }

  // Initialize from XBVR API response
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    duration = try container.decode(TimeInterval.self, forKey: .duration)

    // Parse resolution from string format "1920x1080"
    let resolutionString = try container.decode(String.self, forKey: .resolution)
    let components = resolutionString.split(separator: "x")
    if components.count == 2,
      let width = Double(components[0]),
      let height = Double(components[1]) {
      resolution = CGSize(width: width, height: height)
    } else {
      resolution = CGSize(width: 1920, height: 1080)  // Default resolution
    }

    videoType = try container.decodeIfPresent(VideoType.self, forKey: .videoType) ?? .flat
    stereoMode = try container.decodeIfPresent(StereoMode.self, forKey: .stereoMode) ?? .mono

    let streamURLString = try container.decode(String.self, forKey: .streamURL)
    guard let url = URL(string: streamURLString) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Invalid stream URL")
      )
    }
    streamURL = url

    let thumbnailURLString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
    thumbnailURL = thumbnailURLString.flatMap { URL(string: $0) }

    tags = try container.decodeIfPresent([String].self, forKey: .tags)
    performers = try container.decodeIfPresent([String].self, forKey: .performers)
    studio = try container.decodeIfPresent(String.self, forKey: .studio)
    filePath = try container.decodeIfPresent(String.self, forKey: .filePath)

    let dateString = try container.decodeIfPresent(String.self, forKey: .dateAdded)
    if let dateString = dateString {
      let formatter = ISO8601DateFormatter()
      dateAdded = formatter.date(from: dateString)
    } else {
      dateAdded = nil
    }

    fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
  }

  // Manual initializer for testing/convenience
  init(
    id: String,
    title: String,
    duration: TimeInterval,
    resolution: CGSize,
    videoType: VideoType,
    stereoMode: StereoMode,
    streamURL: URL,
    thumbnailURL: URL? = nil,
    tags: [String]? = nil,
    performers: [String]? = nil,
    studio: String? = nil,
    filePath: String? = nil,
    dateAdded: Date? = nil,
    fileSize: Int64? = nil
  ) {
    self.id = id
    self.title = title
    self.duration = duration
    self.resolution = resolution
    self.videoType = videoType
    self.stereoMode = stereoMode
    self.streamURL = streamURL
    self.thumbnailURL = thumbnailURL
    self.tags = tags
    self.performers = performers
    self.studio = studio
    self.filePath = filePath
    self.dateAdded = dateAdded
    self.fileSize = fileSize
  }

  private enum CodingKeys: String, CodingKey {
    case id, title, duration, resolution, videoType, stereoMode, streamURL, thumbnailURL
    case tags, performers, studio, filePath, dateAdded, fileSize
  }
}

// MARK: - Helper Extensions
extension XBVRVideo {
  /// Returns formatted duration string (e.g., "1h 23m" or "45m 30s")
  var formattedDuration: String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60

    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
      return "\(minutes)m \(seconds)s"
    } else {
      return "\(seconds)s"
    }
  }

  /// Returns formatted file size string (e.g., "2.5 GB")
  var formattedFileSize: String? {
    guard let fileSize = fileSize else { return nil }

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: fileSize)
  }

  /// Returns aspect ratio of the video
  var aspectRatio: Double {
    guard resolution.height > 0 else { return 16.0 / 9.0 }
    return resolution.width / resolution.height
  }

  /// Auto-detects stereo mode based on aspect ratio if not explicitly set
  var detectedStereoMode: StereoMode {
    // If explicitly set and not mono, trust the explicit setting
    if stereoMode != .mono {
      return stereoMode
    }

    // Auto-detect based on aspect ratio
    let ratio = aspectRatio

    // Side-by-Side typically has aspect ratio > 2.0 (e.g., 3840x1080 = 3.56)
    if ratio > 2.0 {
      return .sideBySide
    }
    // Over-Under typically has aspect ratio < 1.0 (e.g., 1920x2160 = 0.89)
    else if ratio < 1.0 {
      return .overUnder
    }
    // Standard aspect ratios default to mono
    else {
      return .mono
    }
  }

  /// Returns true if this is VR content (180° or 360°)
  var isVRContent: Bool {
    return videoType == .vr180 || videoType == .vr360
  }
}
