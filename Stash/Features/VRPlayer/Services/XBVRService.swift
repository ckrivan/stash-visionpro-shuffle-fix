import Combine
import Foundation

/// Service for communicating with Stash server API for VR content
class XBVRService: ObservableObject {
  // MARK: - Configuration

  struct Configuration {
    let baseURL: String
    let apiKey: String?
    let username: String?
    let password: String?
    let timeout: TimeInterval

    init(
      baseURL: String = "http://192.168.86.100:9999",
      apiKey: String? =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo",
      username: String? = nil,
      password: String? = nil,
      timeout: TimeInterval = 30.0
    ) {
      self.baseURL = baseURL
      self.apiKey = apiKey
      self.username = username
      self.password = password
      self.timeout = timeout
    }
  }

  // MARK: - Properties

  @Published var isConnected = false
  @Published var isLoading = false
  @Published var error: Error?

  private let config: Configuration
  private let session: URLSession
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization

  init(config: Configuration = Configuration()) {
    self.config = config

    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = config.timeout
    sessionConfig.timeoutIntervalForResource = config.timeout * 2
    self.session = URLSession(configuration: sessionConfig)

    // Test connection on initialization
    Task {
      await testInitialConnection()
    }
  }

  func testInitialConnection() async {
    do {
      let connected = try await testConnection()
      print("🔄 Initial XBVR connection test: \(connected ? "✅ Connected" : "❌ Failed")")
    } catch {
      print("🔄 Initial XBVR connection failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Connection Management

  /// Tests connection to Stash server (using for VR content)
  func testConnection() async throws -> Bool {
    let url = URL(string: "\(config.baseURL)/graphql")!

    let query = """
      {
          "operationName": "FindScenes",
          "variables": {
              "filter": {
                  "page": 1,
                  "per_page": 1,
                  "sort": "title",
                  "direction": "ASC"
              },
              "scene_filter": {
                  "tags": {
                      "value": ["VR", "180", "360"],
                      "modifier": "INCLUDES"
                  }
              }
          },
          "query": "query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) { findScenes(filter: $filter, scene_filter: $scene_filter) { count scenes { id title } } }"
      }
      """

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    addAuthenticationHeaders(to: &request)
    request.httpBody = query.data(using: .utf8)

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw XBVRError.invalidResponse
    }

    let connected = httpResponse.statusCode == 200

    await MainActor.run {
      self.isConnected = connected
    }

    return connected
  }

  // MARK: - Video Management

  /// Fetches list of VR videos from Stash server
  func fetchVideos(
    limit: Int = 50,
    offset: Int = 0,
    sort: String = "title",
    filter: String? = nil
  ) async throws -> [XBVRVideo] {
    await MainActor.run { isLoading = true }
    defer { Task { await MainActor.run { self.isLoading = false } } }

    let url = URL(string: "\(config.baseURL)/graphql")!

    let page = (offset / limit) + 1

    let query = """
      {
          "operationName": "FindScenes",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": \(limit),
                  "sort": "\(sort)",
                  "direction": "DESC"
              },
              "scene_filter": {
                  "tags": {
                      "value": ["VR", "180", "360"],
                      "modifier": "INCLUDES"
                  }
              }
          },
          "query": "query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) { findScenes(filter: $filter, scene_filter: $scene_filter) { count scenes { id title details duration paths { screenshot preview stream } files { size duration video_codec width height } performers { id name } tags { id name } studio { id name } } } }"
      }
      """

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    addAuthenticationHeaders(to: &request)
    request.httpBody = query.data(using: .utf8)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw XBVRError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw XBVRError.httpError(httpResponse.statusCode)
    }

    do {
      let decoder = JSONDecoder()
      let stashResponse = try decoder.decode(VRStashScenesResponse.self, from: data)
      return stashResponse.data.findScenes.scenes.map { $0.toXBVRVideo(baseURL: config.baseURL) }
    } catch {
      throw XBVRError.decodingError(error)
    }
  }

  /// Fetches detailed information for a specific video
  func fetchVideo(id: String) async throws -> XBVRVideo {
    let url = URL(string: "\(config.baseURL)/api/videos/\(id)")!

    var request = URLRequest(url: url)
    addAuthenticationHeaders(to: &request)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw XBVRError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw XBVRError.httpError(httpResponse.statusCode)
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode(XBVRVideo.self, from: data)
    } catch {
      throw XBVRError.decodingError(error)
    }
  }

  /// Gets stream URL for a video
  func streamURL(for videoId: String, quality: VideoQuality = .original) -> URL {
    var urlString = "\(config.baseURL)/api/dms/file/\(videoId)"

    if quality != .original {
      urlString += "?quality=\(quality.rawValue)"
    }

    // Add API key as query parameter if available
    if let apiKey = config.apiKey {
      let separator = quality == .original ? "?" : "&"
      urlString += "\(separator)apikey=\(apiKey)"
    }

    return URL(string: urlString)!
  }

  /// Gets thumbnail URL for a video
  func thumbnailURL(for videoId: String, timestamp: TimeInterval? = nil) -> URL {
    var urlString = "\(config.baseURL)/api/videos/\(videoId)/thumbnail"

    if let timestamp = timestamp {
      urlString += "?t=\(Int(timestamp))"
    }

    return URL(string: urlString)!
  }

  /// Gets VTT file URL for scrubbing thumbnails
  func vttURL(for videoId: String) -> URL {
    return URL(string: "\(config.baseURL)/api/videos/\(videoId)/thumbnails.vtt")!
  }

  // MARK: - Search and Filtering

  /// Searches videos by query
  func searchVideos(
    query: String,
    limit: Int = 20,
    offset: Int = 0
  ) async throws -> [XBVRVideo] {
    return try await fetchVideos(
      limit: limit,
      offset: offset,
      sort: "relevance",
      filter: query
    )
  }

  /// Fetches videos by category/tag
  func fetchVideosByTag(
    tag: String,
    limit: Int = 50,
    offset: Int = 0
  ) async throws -> [XBVRVideo] {
    return try await fetchVideos(
      limit: limit,
      offset: offset,
      sort: "date_added",
      filter: "tag:\(tag)"
    )
  }

  /// Fetches random videos
  func fetchRandomVideos(count: Int = 10) async throws -> [XBVRVideo] {
    return try await fetchVideos(
      limit: count,
      offset: 0,
      sort: "random"
    )
  }

  // MARK: - Private Helpers

  private func addAuthenticationHeaders(to request: inout URLRequest) {
    // Add API key header if available
    if let apiKey = config.apiKey {
      request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    // Add basic auth if username/password provided
    if let username = config.username,
      let password = config.password {
      let credentials = "\(username):\(password)"
      if let credentialsData = credentials.data(using: .utf8) {
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
      }
    }

    // Standard headers
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("VisionProStashApp/1.0", forHTTPHeaderField: "User-Agent")
  }
}

// MARK: - Supporting Types

/// Video quality options for streaming
enum VideoQuality: String, CaseIterable {
  case original = "original"
  case high = "1080p"
  case medium = "720p"
  case low = "480p"
  case lowest = "240p"

  var displayName: String {
    switch self {
    case .original: return "Original Quality"
    case .high: return "1080p"
    case .medium: return "720p"
    case .low: return "480p"
    case .lowest: return "240p"
    }
  }
}

/// Response structure for Stash scenes API
private struct VRStashScenesResponse: Codable {
  let data: VRStashScenesData
}

private struct VRStashScenesData: Codable {
  let findScenes: VRStashFindScenes
}

private struct VRStashFindScenes: Codable {
  let count: Int
  let scenes: [VRStashScene]
}

/// Stash Scene model from API (simplified for VR use)
private struct VRStashScene: Codable {
  let id: String
  let title: String
  let details: String?
  let duration: Double?
  let paths: VRStashPaths?
  let files: [VRStashFile]?
  let performers: [VRStashPerformer]?
  let tags: [VRStashTag]?
  let studio: VRStashStudio?

  func toXBVRVideo(baseURL: String) -> XBVRVideo {
    // Determine video type based on tags
    let videoType: XBVRVideo.VideoType
    let hasVRTag = tags?.contains { $0.name.lowercased().contains("vr") } ?? false
    let has180Tag = tags?.contains { $0.name.lowercased().contains("180") } ?? false
    let has360Tag = tags?.contains { $0.name.lowercased().contains("360") } ?? false

    if has360Tag {
      videoType = .vr360
    } else if has180Tag || hasVRTag {
      videoType = .vr180
    } else {
      videoType = .flat
    }

    // Determine stereo mode based on tags or title
    let stereoMode: XBVRVideo.StereoMode
    let titleLower = title.lowercased()
    let hasSBSTag =
      tags?.contains {
        $0.name.lowercased().contains("sbs") || $0.name.lowercased().contains("side")
      } ?? false
    let hasOUTag =
      tags?.contains {
        $0.name.lowercased().contains("ou") || $0.name.lowercased().contains("over")
      } ?? false

    if hasSBSTag || titleLower.contains("sbs") || titleLower.contains("side") {
      stereoMode = .sideBySide
    } else if hasOUTag || titleLower.contains("ou") || titleLower.contains("over") {
      stereoMode = .overUnder
    } else {
      stereoMode = .mono
    }

    let streamURL = URL(string: "\(baseURL)/scene/\(id)/stream")!
    let thumbnailURL = paths?.screenshot.flatMap { URL(string: "\(baseURL)\($0)") }

    return XBVRVideo(
      id: id,
      title: title,
      duration: duration ?? 0,
      resolution: CGSize(
        width: CGFloat(files?.first?.width ?? 1920),
        height: CGFloat(files?.first?.height ?? 1080)
      ),
      videoType: videoType,
      stereoMode: stereoMode,
      streamURL: streamURL,
      thumbnailURL: thumbnailURL,
      tags: tags?.map { $0.name },
      performers: performers?.map { $0.name },
      studio: studio?.name,
      filePath: paths?.stream,
      dateAdded: nil,
      fileSize: files?.first?.size
    )
  }
}

private struct VRStashPaths: Codable {
  let screenshot: String?
  let preview: String?
  let stream: String?
}

private struct VRStashFile: Codable {
  let size: Int64?
  let duration: Double?
  let video_codec: String?
  let width: Int?
  let height: Int?
}

private struct VRStashPerformer: Codable {
  let id: String
  let name: String
}

private struct VRStashTag: Codable {
  let id: String
  let name: String
}

private struct VRStashStudio: Codable {
  let id: String
  let name: String
}

/// XBVR-specific errors
enum XBVRError: LocalizedError {
  case invalidURL
  case invalidResponse
  case httpError(Int)
  case decodingError(Error)
  case networkError(Error)
  case authenticationFailed
  case serverUnavailable

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid XBVR server URL"
    case .invalidResponse:
      return "Invalid response from XBVR server"
    case .httpError(let code):
      return "HTTP error: \(code)"
    case .decodingError(let error):
      return "Failed to decode response: \(error.localizedDescription)"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .authenticationFailed:
      return "Authentication failed - check API key or credentials"
    case .serverUnavailable:
      return "XBVR server is unavailable"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .invalidURL:
      return "Check the XBVR server URL in settings"
    case .authenticationFailed:
      return "Verify your API key or username/password"
    case .serverUnavailable:
      return "Ensure XBVR server is running and accessible"
    case .httpError(let code) where code >= 500:
      return "Server error - try again later"
    case .networkError:
      return "Check your network connection"
    default:
      return "Try again or check XBVR server status"
    }
  }
}

// MARK: - Singleton Access

extension XBVRService {
  static let shared = XBVRService()
}
