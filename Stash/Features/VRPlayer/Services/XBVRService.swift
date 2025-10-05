import Combine
import Foundation

/// Service for communicating with XBVR server via DeoVR API for VR content
class XBVRService: ObservableObject {
  // MARK: - Configuration

  struct Configuration {
    let baseURL: String
    let apiKey: String?
    let username: String?
    let password: String?
    let timeout: TimeInterval

    init(
      baseURL: String = "http://192.168.86.100:9998",
      apiKey: String? = nil,
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

  /// Tests connection to XBVR server via DeoVR API
  func testConnection() async throws -> Bool {
    let url = URL(string: "\(config.baseURL)/deovr/")!

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    addAuthenticationHeaders(to: &request)

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

  /// Fetches list of VR videos from XBVR DeoVR API
  func fetchVideos(
    limit: Int = 50,
    offset: Int = 0,
    sort: String = "title",
    filter: String? = nil
  ) async throws -> [XBVRVideo] {
    await MainActor.run { isLoading = true }
    defer { Task { await MainActor.run { self.isLoading = false } } }

    let url = URL(string: "\(config.baseURL)/deovr/")!

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
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
      let libraryResponse = try decoder.decode(DeoVRLibraryResponse.self, from: data)

      print("📦 XBVR: Received \(libraryResponse.scenes.count) playlists")

      // Flatten all playlist items into a single array
      var allVideos: [XBVRVideo] = []
      for playlist in libraryResponse.scenes {
        print("📦 XBVR: Playlist '\(playlist.name)' has \(playlist.list.count) videos")
        for item in playlist.list {
          // Extract scene ID from video_url (format: "/deovr/{scene-id}")
          let sceneId = item.video_url.replacingOccurrences(of: "/deovr/", with: "")
          print("   📝 video_url: '\(item.video_url)' -> sceneId: '\(sceneId)'")

          // Create lightweight XBVRVideo from list item (no full fetch yet)
          let video = item.toXBVRVideo(baseURL: config.baseURL, sceneId: sceneId)
          allVideos.append(video)
        }
      }

      print("📦 XBVR: Total videos collected: \(allVideos.count)")

      // Apply pagination
      let start = min(offset, allVideos.count)
      let end = min(offset + limit, allVideos.count)
      return Array(allVideos[start..<end])
    } catch {
      print("❌ XBVR fetchVideos error: \(error)")
      throw XBVRError.decodingError(error)
    }
  }

  /// Fetches detailed information for a specific video from DeoVR API
  func fetchVideo(id: String) async throws -> XBVRVideo {
    let url = URL(string: "\(config.baseURL)/deovr/\(id)")!

    print("🔍 Fetching video detail from: \(url.absoluteString)")

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    addAuthenticationHeaders(to: &request)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      print("❌ Invalid response from server")
      throw XBVRError.invalidResponse
    }

    print("📡 Response status code: \(httpResponse.statusCode)")

    guard httpResponse.statusCode == 200 else {
      print("❌ HTTP error \(httpResponse.statusCode) for URL: \(url.absoluteString)")
      if let responseString = String(data: data, encoding: .utf8) {
        print("   Response body: \(responseString)")
      }
      throw XBVRError.httpError(httpResponse.statusCode)
    }

    do {
      let decoder = JSONDecoder()
      let deovrScene = try decoder.decode(DeoVRScene.self, from: data)
      print("✅ Successfully decoded scene: \(deovrScene.title)")
      return deovrScene.toXBVRVideo()
    } catch {
      print("❌ JSON decoding error: \(error)")
      if let responseString = String(data: data, encoding: .utf8) {
        print("   Response JSON: \(responseString.prefix(500))")
      }
      throw XBVRError.decodingError(error)
    }
  }

  // NOTE: Stream URLs, thumbnails, and VTT files are provided directly by the DeoVR API
  // in the scene detail response, so these helper methods are not needed

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

/// DeoVR Library Response
private struct DeoVRLibraryResponse: Codable {
  let authorized: String
  let scenes: [DeoVRPlaylist]
}

/// DeoVR Playlist
private struct DeoVRPlaylist: Codable {
  let name: String
  let list: [DeoVRListItem]
}

/// DeoVR List Item (lightweight scene info)
private struct DeoVRListItem: Codable {
  let title: String
  let videoLength: Double?
  let thumbnailUrl: String?
  let video_url: String

  /// Convert DeoVR list item to lightweight XBVRVideo
  func toXBVRVideo(baseURL: String, sceneId: String) -> XBVRVideo {
    // For list items, we create a placeholder stream URL
    // The actual stream URL will be fetched when the user plays the video

    // Safely construct URL - video_url is a path like "/deovr/123"
    let urlString = "\(baseURL)\(video_url)"
    let placeholderURL = URL(string: urlString) ?? URL(string: "about:blank")!

    print("🔗 Creating video: \(title)")
    print("   URL string: \(urlString)")
    print("   Placeholder URL: \(placeholderURL.absoluteString)")

    let thumbURL = thumbnailUrl.flatMap { URL(string: $0) }

    return XBVRVideo(
      id: sceneId,
      title: title,
      duration: videoLength ?? 0,
      resolution: CGSize(width: 1920, height: 1080),  // Default, updated when playing
      videoType: .vr180,  // Default for XBVR content, updated when playing
      stereoMode: .sideBySide,  // Default for XBVR content, updated when playing
      streamURL: placeholderURL,  // Placeholder, updated when playing
      thumbnailURL: thumbURL,
      tags: nil,
      performers: nil,
      studio: nil,
      filePath: nil,
      dateAdded: nil,
      fileSize: nil
    )
  }
}

/// DeoVR Scene Detail Response
private struct DeoVRScene: Codable {
  let id: Int?
  let title: String
  let authorized: Int?
  let description: String?
  let date: Int?
  let actors: [DeoVRActor]?
  let paysite: DeoVRSite?
  let isFavorite: Bool?
  let isScripted: Bool?
  let is3d: Bool?
  let stereoMode: String?
  let screenType: String?
  let videoLength: Double?
  let encodings: [DeoVREncoding]?
  let thumbnailUrl: String?

  struct DeoVRActor: Codable {
    let id: Int?
    let name: String
  }

  struct DeoVRSite: Codable {
    let id: Int?
    let name: String
    let is3rdParty: Bool?
  }

  struct DeoVREncoding: Codable {
    let name: String
    let videoSources: [DeoVRVideoSource]
  }

  struct DeoVRVideoSource: Codable {
    let resolution: Int?
    let height: Int?
    let width: Int?
    let size: Int64?
    let url: String
  }

  /// Convert DeoVR scene to XBVRVideo
  func toXBVRVideo() -> XBVRVideo {
    // Determine video type from screenType
    let videoType: XBVRVideo.VideoType
    switch screenType?.lowercased() {
    case "sphere":
      videoType = .vr360
    case "dome", "fisheye", "mkx200", "rf52":
      videoType = .vr180
    default:
      videoType = .flat
    }

    // Determine stereo mode
    let stereo: XBVRVideo.StereoMode
    if is3d == true {
      switch stereoMode?.lowercased() {
      case "sbs":
        stereo = .sideBySide
      case "tb":
        stereo = .overUnder
      default:
        stereo = .sideBySide  // Default for 3D content
      }
    } else {
      stereo = .mono
    }

    // Get highest quality video source
    let videoSource = encodings?.first?.videoSources.first
    let streamURL = videoSource.flatMap { URL(string: $0.url) } ?? URL(string: "about:blank")!
    let thumbnailURL = thumbnailUrl.flatMap { URL(string: $0) }

    let width = videoSource?.width ?? 1920
    let height = videoSource?.height ?? 1080

    return XBVRVideo(
      id: id.map(String.init) ?? UUID().uuidString,
      title: title,
      duration: videoLength ?? 0,
      resolution: CGSize(width: CGFloat(width), height: CGFloat(height)),
      videoType: videoType,
      stereoMode: stereo,
      streamURL: streamURL,
      thumbnailURL: thumbnailURL,
      tags: nil,  // DeoVR doesn't provide tags in scene response
      performers: actors?.map { $0.name },
      studio: paysite?.name,
      filePath: nil,
      dateAdded: date.map { Date(timeIntervalSince1970: TimeInterval($0)) },
      fileSize: videoSource?.size
    )
  }
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
