import Foundation
import SwiftUI

enum StashAPIError: Error, LocalizedError {
  case graphQLError(String)
  case networkError(Error)
  case decodingError(Error)
  case dataNotFound(String)
  case invalidURL
  case invalidResponse
  case serverError(Int)
  case connectionFailed(String)
  case authenticationFailed
  case emptyResponse
  case invalidData(String)

  var errorDescription: String? {
    switch self {
    case .graphQLError(let message):
      return "GraphQL Error: \(message)"
    case .networkError(let error):
      return "Network Error: \(error.localizedDescription)"
    case .decodingError(let error):
      return "Decoding Error: \(error.localizedDescription)"
    case .dataNotFound(let message):
      return "Data Not Found: \(message)"
    case .invalidURL:
      return "Invalid URL"
    case .invalidResponse:
      return "Invalid Server Response"
    case .serverError(let code):
      return "Server Error (\(code))"
    case .connectionFailed(let reason):
      return "Connection Failed: \(reason)"
    case .authenticationFailed:
      return "Authentication Failed"
    case .emptyResponse:
      return "Server returned empty response"
    case .invalidData(let details):
      return "Invalid Data: \(details)"
    }
  }
}

struct GraphQLDataWrapper<T: Decodable>: Decodable {
  let data: T
}
/// Response payload for deleteScenes mutation
private struct ScenesDestroyData: Decodable {
  /// True if deletion succeeded
  let scenesDestroy: Bool
}

@MainActor
class StashAPI: ObservableObject {
  @Published var scenes: [StashScene] = []
  @Published var performers: [StashScene.Performer] = []
  @Published var markers: [SceneMarker] = []
  @Published var isLoading = false
  @Published var error: Error?
  @Published var serverAddressPublic = ""
  @Published var preview: Bool = false
  @Published var totalSceneCount: Int = 0
  @Published var totalMarkerCount: Int = 0
  @Published var connectionStatus: ConnectionStatus = .unknown
  @Published var sceneID: String?

  // Network monitoring for VPN detection
  @Published var networkMonitor = NetworkMonitor()

  enum ConnectionStatus: Equatable {
    case connected
    case disconnected
    case authenticationFailed
    case unknown
    case failed(Error)

    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
      switch (lhs, rhs) {
      case (.connected, .connected),
        (.disconnected, .disconnected),
        (.authenticationFailed, .authenticationFailed),
        (.unknown, .unknown):
        return true
      case (.failed(let lhsError), .failed(let rhsError)):
        return lhsError.localizedDescription == rhsError.localizedDescription
      default:
        return false
      }
    }
  }

  // Hardcoded values for local development
  private let localServerAddress = "http://192.168.86.100:9999"
  private let wsServerAddress = "ws://192.168.86.100:9999"
  private let localApiKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

  var serverAddress: String {
    // Use hardcoded value for now
    localServerAddress
  }

  var wsAddress: String {
    // Use hardcoded value for now
    wsServerAddress
  }

  var apiKey: String {
    // Use hardcoded value for now
    localApiKey
  }

  init() {
    print("🔄 StashAPI initializing with server: \(serverAddress)")

    // Trigger a connection check asynchronously
    Task {
      await checkAndUpdateConnectionStatus()
    }
  }

  // Check server connection and update the connectionStatus property
  private func checkAndUpdateConnectionStatus() async {
    print("🔄 Checking connection status...")
    do {
      // Try to connect to the server
      try await checkServerConnection()
      await MainActor.run {
        self.connectionStatus = .connected
        self.error = nil
        print("✅ Connection successful")
      }
    } catch let error as StashAPIError {
      await MainActor.run {
        switch error {
        case .authenticationFailed:
          print("🔒 Authentication failed - check API key")
          self.connectionStatus = .authenticationFailed
        case .connectionFailed(let reason):
          print("❌ Connection failed: \(reason)")
          self.connectionStatus = .disconnected
        case .invalidURL:
          print("❌ Invalid server URL configured")
          self.connectionStatus = .failed(error)
        default:
          print("❌ Connection error: \(error.localizedDescription)")
          self.connectionStatus = .failed(error)
        }
        self.error = error
      }

      // Try to determine if server is reachable without authentication
      do {
        guard let url = URL(string: serverAddress) else {
          return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
          print("📡 Basic server check response: \(httpResponse.statusCode)")

          await MainActor.run {
            if (200...299).contains(httpResponse.statusCode) {
              // Server is reachable but we had auth issues
              if self.connectionStatus != .authenticationFailed {
                self.connectionStatus = .authenticationFailed
              }
            } else if (500...599).contains(httpResponse.statusCode) {
              self.connectionStatus = .failed(StashAPIError.serverError(httpResponse.statusCode))
            }
          }
        }
      } catch {
        print("❌ Server completely unreachable: \(error.localizedDescription)")
        await MainActor.run {
          self.connectionStatus = .disconnected
        }
      }
    } catch {
      print("❌ Unexpected error during connection check: \(error.localizedDescription)")
      await MainActor.run {
        self.connectionStatus = .failed(error)
        self.error = error
      }
    }
  }

  // Helper method to retry connection
  func retryConnection() async {
    print("🔄 Retrying connection...")
    await checkAndUpdateConnectionStatus()
  }

  // Helper to check if we're properly connected
  var isConnected: Bool {
    connectionStatus == .connected
  }

  // Helper to get a user-friendly connection status message
  var connectionStatusMessage: String {
    switch connectionStatus {
    case .connected:
      return "Connected to server"
    case .disconnected:
      return "Unable to connect to server"
    case .authenticationFailed:
      return "Authentication failed - check API key"
    case .unknown:
      return "Checking connection..."
    case .failed(let error):
      if let stashError = error as? StashAPIError {
        return stashError.localizedDescription
      } else {
        return "Connection failed: \(error.localizedDescription)"
      }
    }
  }

  // MARK: - Scene Methods

  func getStreamURL(forSceneID id: String, useHLS: Bool = true, startTime: Double? = nil) async
    -> URL?
  {
    // First try to get the scene to check its format
    do {
      if let scene = try await fetchScene(byID: id) {
        // Check if any file is MP4
        let isH264 =
          scene.files?.contains { file in
            file.video_codec?.lowercased().contains("h264") ?? false
          } ?? false

        if isH264 {
          print("📽 Using direct stream for H.264")
          return getDirectStreamURL(forSceneID: id, startTime: startTime)
        } else {
          print("📽 Using HLS for non-H.264 codec")
          return getHLSStreamURL(forSceneID: id, startTime: startTime)
        }
      }
    } catch {
      print("❌ Failed to fetch scene info for format check: \(error.localizedDescription)")
    }

    // Fall back to direct streaming if we can't check format
    print("📽 Falling back to direct stream")
    return getDirectStreamURL(forSceneID: id, startTime: startTime)
  }

  private func getDirectStreamURL(forSceneID id: String, startTime: Double? = nil) -> URL? {
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)/stream") else {
      return nil
    }

    var queryItems = [URLQueryItem]()

    if let startTime = startTime {
      queryItems.append(URLQueryItem(name: "t", value: String(Int(startTime))))
    }

    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    components.queryItems = queryItems
    return components.url
  }

  private func getHLSStreamURL(
    forSceneID id: String, startTime: Double? = nil, resolution: String = "ORIGINAL"
  ) -> URL? {
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)/stream.m3u8") else {
      return nil
    }

    var queryItems = [URLQueryItem]()

    // IMPORTANT: Add the apikey first to match the format expected by Stash
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    // Add resolution parameter - options are: 240p, 480p, 720p, 1080p, 4k, original
    queryItems.append(URLQueryItem(name: "resolution", value: resolution))

    // Add start time last if specified
    if let startTime = startTime {
      queryItems.append(URLQueryItem(name: "t", value: String(Int(startTime))))
    }

    // Add a timestamp to prevent caching issues
    let timestamp = Int(Date().timeIntervalSince1970)
    queryItems.append(URLQueryItem(name: "_ts", value: "\(timestamp)"))

    components.queryItems = queryItems

    let url = components.url
    print("🎬 Created HLS stream URL: \(url?.absoluteString ?? "nil")")
    print("🎬 Using \(resolution) resolution for HLS stream")

    return url
  }

  /// Get a transcoded HLS URL with a specific resolution for better compatibility
  /// - Parameters:
  ///   - id: The scene ID
  ///   - resolution: The resolution to use (240p, 480p, 720p, 1080p, 4k, original)
  ///   - startTime: Optional start time in seconds
  /// - Returns: URL for the transcoded HLS stream
  func getTranscodedHLSStreamURL(
    forSceneID id: String, resolution: String = "720p", startTime: Double? = nil
  ) -> URL? {
    return getHLSStreamURL(forSceneID: id, startTime: startTime, resolution: resolution)
  }

  func getStreamRequest(forSceneID id: String, useHLS: Bool = true, startTime: Double? = nil) async
    -> URLRequest?
  {
    print("🎬 Creating stream request for scene \(id), useHLS: \(useHLS)")

    // First try to get the scene to check if it's VR content and check codec
    var isVRContent = false
    var isHEVCVideo = false
    var shouldUseHLS = useHLS  // Create a mutable copy of the parameter
    var requestResolution = "ORIGINAL"  // Default resolution

    do {
      if let scene = try await fetchScene(byID: id) {
        // Check if this is VR content based on tags
        isVRContent =
          scene.tags?.contains {
            $0.name.lowercased() == "vr" || $0.name.lowercased().contains("180")
              || $0.name.lowercased().contains("360")
          } ?? false

        // Check if this is a problematic codec (HEVC/H.265 or WMV)
        isHEVCVideo =
          scene.files?.contains { file in
            let codec = file.video_codec?.lowercased() ?? ""
            return codec.contains("hevc") || codec.contains("h265") || codec.contains("h.265")
              || codec.contains("wmv") || codec.contains("msmpeg") || codec.contains("vc-1")
          } ?? false

        // If it's an HEVC/H.265 file, follow Stash's example and use HLS by default
        if isHEVCVideo && !isVRContent {
          print("🎬 Following Stash's lead: Using HLS mode by default for HEVC content")
          shouldUseHLS = true
        }

        // Add more detailed logging about container and codec
        var containerInfo = "unknown"
        var codecInfo = "unknown"

        if let firstFile = scene.files?.first {
          // SceneFile doesn't have a path property, so we'll use other methods
          // to determine the container format

          // First try to get it from scene paths
          if let streamPath = scene.paths.stream {
            let url = URL(string: streamPath) ?? URL(fileURLWithPath: streamPath)
            containerInfo = url.pathExtension.lowercased()
          }

          // Get codec info
          if let codec = firstFile.video_codec {
            codecInfo = codec.lowercased()
          }
        }

        print("🎬 Scene \(id) details:")
        print("   - Is VR content: \(isVRContent)")
        print("   - Container format: \(containerInfo)")
        print("   - Video codec: \(codecInfo)")
        print("   - Uses problematic codec: \(isHEVCVideo)")

        // For VR content, always use direct streaming regardless of what was requested
        if isVRContent && shouldUseHLS {
          print("🎬 Overriding to use direct streaming for VR content")
          // Override to direct streaming for VR content
          shouldUseHLS = false
        }

        // For HEVC videos with HLS, use a transcoded resolution for better compatibility
        if isHEVCVideo && shouldUseHLS {
          // Use 720p for HEVC/H.265 videos to ensure compatibility
          requestResolution = "720p"
          print("🎬 Using 720p transcoded stream for HEVC video")
        }
      }
    } catch {
      print("❌ Failed to fetch scene info for format check: \(error.localizedDescription)")
      // Continue with the requested streaming method
    }

    // Log the chosen streaming mode
    print("🎬 Using \(shouldUseHLS ? "HLS" : "direct") streaming for this request")

    // Create URL based on streaming method
    let url: URL?

    if shouldUseHLS {
      print("🎬 Using HLS streaming with \(requestResolution) resolution")
      if isHEVCVideo {
        // Use getTranscodedHLSStreamURL for HEVC videos to ensure compatibility
        url = getTranscodedHLSStreamURL(
          forSceneID: id, resolution: requestResolution, startTime: startTime)
      } else {
        // Use standard HLS URL for non-HEVC videos
        url = getHLSStreamURL(forSceneID: id, startTime: startTime, resolution: requestResolution)
      }
    } else {
      print("🎬 Using direct streaming")
      url = getDirectStreamURL(forSceneID: id, startTime: startTime)
    }

    guard let url = url else {
      print("❌ Failed to create URL")
      return nil
    }

    print("🎬 Created stream URL: \(url.absoluteString)")

    var request = URLRequest(url: url)

    if shouldUseHLS {
      // For HLS streams, set the right Accept header for M3U8 format
      request.setValue("application/vnd.apple.mpegurl, */*;q=0.8", forHTTPHeaderField: "Accept")
      // For debugging, log the mime type
      print("🎬 HLS MODE: Set Accept: application/vnd.apple.mpegurl")
    } else {
      request.setValue("*/*", forHTTPHeaderField: "Accept")
    }

    request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")  // Add Bearer token auth
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.setValue(
      "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
      forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Playback-Session-Id")
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue("\(serverAddress)/scenes/\(id)", forHTTPHeaderField: "Referer")

    // Add diagnostics information
    print("🔑 Authentication headers set: ApiKey and Bearer token")

    return request
  }

  // MARK: - VPN-Optimized Streaming Methods

  /// Get an optimized stream request based on current network conditions
  /// This method reduces handshakes and API calls when on VPN
  func getOptimizedStreamRequest(forSceneID id: String, startTime: Double? = nil) async
    -> URLRequest?
  {
    let networkMode = networkMonitor.networkMode

    print("🌐 Getting optimized stream for network mode: \(networkMode.description)")

    // CRITICAL: Check for user's saved HLS preference first
    let userHasHLSPreference = UserDefaults.standard.object(forKey: "player_use_hls_mode") != nil
    if userHasHLSPreference {
      let savedHLSMode = UserDefaults.standard.bool(forKey: "player_use_hls_mode")
      print("📱 Using saved user HLS preference: \(savedHLSMode ? "HLS" : "Direct")")
      return await getStreamRequest(forSceneID: id, useHLS: savedHLSMode, startTime: startTime)
    }

    // If no user preference, use network-optimized defaults
    print("🔧 No user HLS preference found, using network-optimized defaults")

    switch networkMode {
    case .local:
      // Use full-featured approach for local network
      print("🎬 Using full-featured local streaming")
      return await getStreamRequest(forSceneID: id, useHLS: false, startTime: startTime)

    case .vpn:
      // Prefer HLS on VPN for reliability (direct often stalls over VPN)
      print("🎬 Using VPN-optimized streaming (prefer HLS)")
      return await getStreamRequest(forSceneID: id, useHLS: true, startTime: startTime)

    case .remote:
      // Use HLS for better reliability over internet
      print("🎬 Using remote-optimized streaming (HLS)")
      return await getStreamRequest(forSceneID: id, useHLS: true, startTime: startTime)
    }
  }

  /// VPN-optimized streaming request that minimizes API calls and uses single auth
  private func getVPNOptimizedRequest(forSceneID id: String, startTime: Double? = nil) async
    -> URLRequest?
  {
    print("🔧 Creating VPN-optimized request for scene \(id)")

    // Skip codec detection - default to direct streaming for VPN
    // This eliminates the fetchScene API call that checks codec
    let url = getDirectStreamURL(forSceneID: id, startTime: startTime)

    guard let url = url else {
      print("❌ Failed to create VPN-optimized direct stream URL")
      return nil
    }

    print("🎬 VPN-optimized URL: \(url.absoluteString)")

    var request = URLRequest(url: url)

    // Use only Bearer token authentication for VPN (most efficient)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue(
      "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15",
      forHTTPHeaderField: "User-Agent")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Playback-Session-Id")

    // Add VPN optimization header for debugging
    request.setValue("vpn-optimized", forHTTPHeaderField: "X-Stream-Mode")

    print("🔑 VPN-optimized: Using single Bearer token authentication")

    return request
  }

  /// Fallback method for VPN that uses HLS if direct streaming fails
  func getVPNHLSFallbackRequest(forSceneID id: String, startTime: Double? = nil) async
    -> URLRequest?
  {
    print("🔄 Creating VPN HLS fallback request for scene \(id)")

    // Use HLS with 720p transcoding for better VPN compatibility
    let url = getTranscodedHLSStreamURL(forSceneID: id, resolution: "720p", startTime: startTime)

    guard let url = url else {
      print("❌ Failed to create VPN HLS fallback URL")
      return nil
    }

    print("🎬 VPN HLS fallback URL: \(url.absoluteString)")

    var request = URLRequest(url: url)

    // Use single Bearer token auth for VPN
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.apple.mpegurl, */*;q=0.8", forHTTPHeaderField: "Accept")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue(
      "Mozilla/5.0 (Apple Vision; Vision Pro) AppleWebKit/605.1.15",
      forHTTPHeaderField: "User-Agent")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Playback-Session-Id")

    // Add VPN fallback header for debugging
    request.setValue("vpn-hls-fallback", forHTTPHeaderField: "X-Stream-Mode")

    print("🔑 VPN HLS fallback: Using single Bearer token authentication")

    return request
  }

  /// Check if we should defer thumbnail/VTT loading based on network mode
  var shouldDeferThumbnails: Bool {
    return networkMonitor.networkMode == .vpn
  }

  /// Get network-optimized streaming strategy
  var streamingStrategy: String {
    switch networkMonitor.networkMode {
    case .local:
      return "Full-featured with codec detection"
    case .vpn:
      return "Minimal handshakes, direct streaming preferred"
    case .remote:
      return "HLS transcoding for reliability"
    }
  }

  func fetchScenes(
    page: Int = 1, sort: String = "file_mod_time", appendResults: Bool = false,
    customQuery: String? = nil
  ) async throws {
    isLoading = true

    let randomSeed = Int.random(in: 0...999999)
    let sortField = sort == "random" ? "random_\(randomSeed)" : sort

    let query =
      customQuery ?? """
        {
            "operationName": "FindScenes",
            "variables": {
                "filter": {
                    "page": \(page),
                    "per_page": 20,
                    "sort": "\(sortField)",
                    "direction": "DESC"
                }
            },
            "query": "query FindScenes($filter: FindFilterType) { findScenes(filter: $filter) { count scenes { id title details url date rating100 organized o_counter paths { screenshot preview stream webp vtt sprite funscript interactive_heatmap } files { size duration video_codec width height } performers { id name gender } tags { id name } studio { id name } stash_ids { endpoint stash_id } created_at updated_at } } }"
        }
        """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for scenes")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = query.data(using: .utf8)

    do {
      let (data, httpResponse) = try await URLSession.shared.data(for: request)

      if let httpResponse = httpResponse as? HTTPURLResponse {
        print("📥 Scenes response status: \(httpResponse.statusCode)")
      }

      // Removed full response logging for performance

      let scenesResponse = try JSONDecoder().decode(ScenesResponse.self, from: data)

      if appendResults {
        // Filter out duplicates before appending
        let newScenes = scenesResponse.data.findScenes.scenes.filter { newScene in
          !self.scenes.contains { $0.id == newScene.id }
        }
        self.scenes.append(contentsOf: newScenes)
      } else {
        self.scenes = scenesResponse.data.findScenes.scenes
      }
    } catch {
      print(" Error loading scenes: \(error)")
      self.error = error
    }

    isLoading = false
  }

  func updateScene(id: String, tagIds: [String]) async throws -> StashScene {
    isLoading = true
    defer { isLoading = false }

    let query = """
      {
          "operationName": "SceneUpdate",
          "variables": {
              "input": {
                  "id": "\(id)",
                  "tag_ids": [\(tagIds.map { "\"\($0)\"" }.joined(separator: ","))]
              }
          },
          "query": "mutation SceneUpdate($input: SceneUpdateInput!) { sceneUpdate(input: $input) { id title details paths { screenshot preview stream } files { size duration video_codec width height } performers { id name } tags { id name } rating100 } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = query.data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(SceneUpdateResponse.self, from: data)
    return response.data.sceneUpdate
  }
  /// Delete a scene by its ID (also deletes the file and generated assets)
  /// - Parameter id: The scene ID to delete
  /// - Throws: StashAPIError on failure
  func deleteScene(id: String) async throws {
    isLoading = true
    defer { isLoading = false }
    // Build GraphQL mutation for ScenesDestroy
    let deleteFile = true
    let deleteGenerated = true
    let variables: [String: Any] = [
      "ids": [id],
      "delete_file": deleteFile,
      "delete_generated": deleteGenerated,
    ]
    // Construct JSON body
    let payload: [String: Any] = [
      "operationName": "ScenesDestroy",
      "variables": variables,
      "query":
        "mutation ScenesDestroy($ids: [ID!]!, $delete_file: Boolean, $delete_generated: Boolean) { scenesDestroy(input: {ids: $ids, delete_file: $delete_file, delete_generated: $delete_generated}) }",
    ]
    let bodyData = try JSONSerialization.data(withJSONObject: payload, options: [])
    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = bodyData
    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw StashAPIError.networkError(URLError(.badServerResponse))
    }
    // Decode GraphQL response using shared model
    let resp = try JSONDecoder().decode(GraphQLResponse<ScenesDestroyData>.self, from: data)
    if let errors = resp.errors, !errors.isEmpty {
      let msgs = errors.map { $0.message }.joined(separator: "\n")
      throw StashAPIError.graphQLError(msgs)
    }
    let result = resp.data
    guard result.scenesDestroy else {
      throw StashAPIError.graphQLError("Server failed to delete scene(s)")
    }
  }

  func searchScenes(query: String) async {
    isLoading = true

    // Escape special characters in the search term
    let escaped =
      query
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    // Use filter.q for full-text search across scenes
    let graphQLQuery = """
      {
          "operationName": "FindScenes",
          "variables": {
              "filter": {
                  "q": "\(escaped)",
                  "page": 1,
                  "per_page": 40,
                  "sort": "title",
                  "direction": "ASC"
              }
          },
          "query": "query FindScenes($filter: FindFilterType) { findScenes(filter: $filter) { count scenes { id title details url date rating100 organized o_counter paths { screenshot preview stream } files { size duration video_codec width height } performers { id name } tags { id name } studio { id name } stash_ids { endpoint stash_id } created_at updated_at } } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print("❌ Invalid URL for scene search")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
    request.httpBody = graphQLQuery.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      if let jsonString = String(data: data, encoding: .utf8) {
        print("📥 Received response: \(jsonString)")
      }
      let response = try JSONDecoder().decode(ScenesResponse.self, from: data)

      await MainActor.run {
        self.scenes = response.data.findScenes.scenes
        print("🔍 Found \(response.data.findScenes.scenes.count) scenes matching '\(query)'")
      }
    } catch {
      print("❌ Error searching scenes: \(error)")
      self.error = error
    }

    isLoading = false
  }

  // MARK: - Performer Methods

  /// Fetch performers with optional scene-count filter and search query
  /// - Parameters:
  ///   - filter: scene count filter
  ///   - page: page number
  ///   - appendResults: whether to append to existing results
  ///   - search: optional search string (filters performer name)
  func fetchPerformers(
    filter: PerformerFilter = .all, page: Int = 1, appendResults: Bool = false, search: String = ""
  ) async {
    isLoading = true

    let sceneCountValue: String
    switch filter {
    case .all:
      sceneCountValue = "0"
    case .lessThanTwo:
      sceneCountValue = "2"
    case .twoOrMore:
      sceneCountValue = "2"
    case .tenOrMore:
      sceneCountValue = "10"
    }

    let sceneCountModifier = filter == .lessThanTwo ? "LESS_THAN" : "GREATER_THAN"

    let escapedQuery = search.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
      of: "\"", with: "\\\"")
    let query = """
      {
          "operationName": "FindPerformers",
          "variables": {
              "filter": {
                  "q": "\(escapedQuery)",
                  "page": \(page),
                  "per_page": 25,
                  "sort": "name",
                  "direction": "ASC"
              },
              "performer_filter": {
                  "gender": {
                      "value_list": ["FEMALE"],
                      "modifier": "INCLUDES"
                  },
                  "scene_count": {
                      "modifier": "\(sceneCountModifier)",
                      "value": "\(sceneCountValue)"
                  }
              }
          },
          "query": "query FindPerformers($filter: FindFilterType, $performer_filter: PerformerFilterType, $performer_ids: [Int!]) { findPerformers(filter: $filter, performer_filter: $performer_filter, performer_ids: $performer_ids) { count performers { id name disambiguation urls gender birthdate ethnicity country eye_color height_cm measurements fake_tits career_length tattoos piercings alias_list favorite ignore_auto_tag image_path scene_count image_count gallery_count group_count performer_count o_counter tags { id name } stash_ids { stash_id endpoint } rating100 details death_date hair_color weight } } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for performers")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = query.data(using: .utf8)

    do {
      let (data, httpResponse) = try await URLSession.shared.data(for: request)

      if let httpResponse = httpResponse as? HTTPURLResponse {
        print(" Response status: \(httpResponse.statusCode)")
      }
      if let responseString = String(data: data, encoding: .utf8) {
        print(" Response data: \(responseString)")
      }

      let decodedResponse = try JSONDecoder().decode(PerformersResponse.self, from: data)
      print(" Total performers count: \(decodedResponse.data.findPerformers.count)")
      print(" Current page: \(page)")
      print(" Performers in response: \(decodedResponse.data.findPerformers.performers.count)")

      await MainActor.run {
        if appendResults {
          // Filter out duplicates before appending
          let newPerformers = decodedResponse.data.findPerformers.performers.filter {
            newPerformer in
            !self.performers.contains { $0.id == newPerformer.id }
          }
          self.performers.append(contentsOf: newPerformers)
          print(" Added \(newPerformers.count) new performers")
        } else {
          self.performers = decodedResponse.data.findPerformers.performers
          print(" Set \(decodedResponse.data.findPerformers.performers.count) performers")
        }
      }
    } catch {
      print(" Error loading performers: \(error)")
      if let decodingError = error as? DecodingError {
        print(" Decoding error details: \(decodingError)")
      }
      self.error = error
    }

    isLoading = false
  }

  // MARK: - Marker Methods

  func fetchMarkers(page: Int = 1, appendResults: Bool = false, performerId: String? = nil) async {
    isLoading = true

    // Generate a random seed for consistent random sorting
    let randomSeed = Int.random(in: 0...999999)

    let graphQLQuery = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": 25,
                  "sort": "random_\(randomSeed)",
                  "direction": "ASC"
              },
              "scene_marker_filter": {
                  \(performerId != nil ? "\"performers\": {\"value\": [\"\(performerId!)\"], \"modifier\": \"INCLUDES_ALL\"}" : "")
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path __typename } performers { id name image_path __typename } __typename }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for markers")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("u=3, i", forHTTPHeaderField: "Priority")
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue("\(serverAddress)/scenes/markers", forHTTPHeaderField: "Referer")
    request.httpBody = graphQLQuery.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let response = try JSONDecoder().decode(SceneMarkersResponse.self, from: data)

      await MainActor.run {
        // Always set the total count for pagination
        self.totalMarkerCount = response.data.findSceneMarkers.count

        if appendResults {
          // Filter out duplicates before appending
          let newMarkers = response.data.findSceneMarkers.scene_markers.filter { newMarker in
            !self.markers.contains { $0.id == newMarker.id }
          }
          self.markers.append(contentsOf: newMarkers)
          print(
            " Added \(newMarkers.count) new markers (total: \(self.markers.count)/\(self.totalMarkerCount))"
          )
        } else {
          self.markers = response.data.findSceneMarkers.scene_markers
          print(
            " Set \(response.data.findSceneMarkers.scene_markers.count) markers (total available: \(self.totalMarkerCount))"
          )
        }
      }
    } catch {
      print(" Error loading markers: \(error)")
      self.error = error
    }

    isLoading = false
  }

  func searchMarkers(query: String) async {
    isLoading = true

    let graphQLQuery = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "q": "\(query)",
                  "page": 1,
                  "per_page": 40,
                  "sort": "title",
                  "direction": "ASC"
              },
              "scene_marker_filter": {}
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path __typename } performers { id name image_path __typename } __typename }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for marker search")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("u=3, i", forHTTPHeaderField: "Priority")
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue("\(serverAddress)/scenes/markers", forHTTPHeaderField: "Referer")
    request.httpBody = graphQLQuery.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let response = try JSONDecoder().decode(SceneMarkersResponse.self, from: data)

      await MainActor.run {
        self.markers = response.data.findSceneMarkers.scene_markers
        print(
          " Found \(response.data.findSceneMarkers.scene_markers.count) markers matching '\(query)'"
        )
      }
    } catch {
      print(" Error searching markers: \(error)")
      self.error = error
    }

    isLoading = false
  }

  // MARK: - Tag Methods

  /// Perform equal random selection from a set of tags
  /// Each tag gets equal probability regardless of marker count or weights
  /// This ensures fair representation of all tag groups
  private func selectWeightedRandomTag(from tagIds: Set<String>, weights: [String: Int]) -> String?
  {
    // Convert set to array for random selection
    let tagArray = Array(tagIds)

    // If no tags, return nil
    guard !tagArray.isEmpty else { return nil }

    // Equal probability selection - each tag has the same chance
    let randomIndex = Int.random(in: 0..<tagArray.count)
    return tagArray[randomIndex]
  }

  /// Fetch a single random marker with optional tag filters or performer filter
  func fetchRandomMarker(
    tagIds: Set<String>? = nil, searchQuery: String? = nil, performerId: String? = nil,
    tagWeights: [String: Int]? = nil
  ) async -> SceneMarker? {
    print(
      "🎲 fetchRandomMarker called with tagIds: \(tagIds?.description ?? "nil"), searchQuery: \(searchQuery ?? "nil"), performerId: \(performerId ?? "nil")"
    )
    print("🎲 Tag weights: \(tagWeights?.description ?? "nil")")

    // Generate a random seed for this request
    let randomSeed = Int.random(in: 0...999999)
    print("🎲 Using random seed: \(randomSeed)")

    // If we have multiple tags, apply equal random selection
    var effectiveTagIds = tagIds
    if let tagIds = tagIds, tagIds.count > 1 {
      let equalPercentage = 100.0 / Double(tagIds.count)
      print("🎲 Equal tag distribution:")
      for tagId in tagIds {
        print("   - Tag \(tagId): \(String(format: "%.1f", equalPercentage))% chance")
      }

      // Perform equal random selection
      let selectedTagId = selectWeightedRandomTag(from: tagIds, weights: tagWeights ?? [:])
      if let selectedTag = selectedTagId {
        effectiveTagIds = Set([selectedTag])
        print("🎲 Equal selection chose tag: \(selectedTag)")
      }
    }

    // Build filters
    var sceneMarkerFilterParts: [String] = []

    // Add tag filter if tags are provided
    if let effectiveTagIds = effectiveTagIds, !effectiveTagIds.isEmpty {
      let tagArray = effectiveTagIds.map { "\"\($0)\"" }.joined(separator: ", ")
      sceneMarkerFilterParts.append(
        """
            "tags": {
                "value": [\(tagArray)],
                "modifier": "INCLUDES"
            }
        """)
    }

    // Add performer filter if performer is provided
    if let performerId = performerId {
      sceneMarkerFilterParts.append(
        """
            "performers": {
                "value": ["\(performerId)"],
                "modifier": "INCLUDES_ALL"
            }
        """)
    }

    // Build search query if provided
    let searchParam = searchQuery ?? ""

    let graphQLQuery: String

    if sceneMarkerFilterParts.isEmpty {
      // Query without scene_marker_filter
      graphQLQuery = """
        {
            "operationName": "FindSceneMarkers",
            "variables": {
                "filter": {
                    "q": "\(searchParam)",
                    "page": 1,
                    "per_page": 1,
                    "sort": "random_\(randomSeed)",
                    "direction": "ASC"
                }
            },
            "query": "query FindSceneMarkers($filter: FindFilterType) { findSceneMarkers(filter: $filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path video_codec __typename } performers { id name image_path gender __typename } __typename }"
        }
        """
    } else {
      // Query with scene_marker_filter
      graphQLQuery = """
        {
            "operationName": "FindSceneMarkers",
            "variables": {
                "filter": {
                    "q": "\(searchParam)",
                    "page": 1,
                    "per_page": 1,
                    "sort": "random_\(randomSeed)",
                    "direction": "ASC"
                },
                "scene_marker_filter": {
                    \(sceneMarkerFilterParts.joined(separator: ",\n                    "))
                }
            },
            "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path video_codec __typename } performers { id name image_path gender __typename } __typename }"
        }
        """
    }

    do {
      print("🎲 Making GraphQL request for random marker...")
      let data = try await performGraphQLRequest(query: graphQLQuery)
      print("🎲 GraphQL request completed, decoding response...")

      let decoder = JSONDecoder()
      let markersResponse = try decoder.decode(SceneMarkersResponse.self, from: data)
      print(
        "🎲 Response decoded - found \(markersResponse.data.findSceneMarkers.count) total markers, \(markersResponse.data.findSceneMarkers.scene_markers.count) returned"
      )

      // Return the first (and only) marker
      let randomMarker = markersResponse.data.findSceneMarkers.scene_markers.first
      if let marker = randomMarker {
        print(
          "🎲 Successfully fetched random marker: \(marker.title) (ID: \(marker.id)) at \(marker.seconds)s"
        )
      } else {
        print("🎲 No random marker found in response")
      }
      return randomMarker
    } catch {
      print("❌ Error fetching random marker: \(error)")
      if let decodingError = error as? DecodingError {
        print("❌ Decoding error details: \(decodingError)")
      }
      return nil
    }
  }

  func fetchMarkersByTag(tagId: String, page: Int = 1, appendResults: Bool = false) async {
    isLoading = true

    let graphQLQuery = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": 25,
                  "sort": "title",
                  "direction": "ASC"
              },
              "scene_marker_filter": {
                  "tags": {
                      "value": ["\(tagId)"],
                      "modifier": "INCLUDES_ALL"
                  }
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path __typename } performers { id name image_path __typename } __typename }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for markers by tag")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("u=3, i", forHTTPHeaderField: "Priority")
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue("\(serverAddress)/scenes/markers", forHTTPHeaderField: "Referer")
    request.httpBody = graphQLQuery.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let response = try JSONDecoder().decode(SceneMarkersResponse.self, from: data)

      await MainActor.run {
        if appendResults {
          // Filter out duplicates before appending
          let newMarkers = response.data.findSceneMarkers.scene_markers.filter { newMarker in
            !self.markers.contains { $0.id == newMarker.id }
          }
          self.markers.append(contentsOf: newMarkers)
          print(" Added \(newMarkers.count) new markers for tag \(tagId)")
        } else {
          self.markers = response.data.findSceneMarkers.scene_markers
          print(
            " Set \(response.data.findSceneMarkers.scene_markers.count) markers for tag \(tagId)")
        }
      }
    } catch {
      print(" Error loading markers by tag: \(error)")
      self.error = error
    }

    isLoading = false
  }

  /// Fetch markers matching ALL selected tags (multi-tag filtering, paginated)
  func fetchMarkersByTags(
    tagIds: [String], page: Int = 1, perPage: Int = 25, appendResults: Bool = false
  ) async {
    isLoading = true
    let tagArray = tagIds.map { "\"\($0)\"" }.joined(separator: ", ")
    let query = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": \(perPage),
                  "sort": "created_at",
                  "direction": "DESC"
              },
              "scene_marker_filter": {
                  "tags": {
                      "value": [\(tagArray)],
                      "modifier": "INCLUDES_ALL"
                  }
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { id title seconds end_seconds stream preview screenshot scene { id title files { width height path } performers { id name image_path } } primary_tag { id name } tags { id name } } } }"
      }
      """
    do {
      let data = try await executeGraphQLQuery(query)
      struct MarkersResponseData: Decodable {
        let data: MarkerData
        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload
          struct MarkersPayload: Decodable {
            let count: Int
            let scene_markers: [SceneMarker]
          }
        }
      }
      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)
      await MainActor.run {
        if appendResults {
          let newMarkers = response.data.findSceneMarkers.scene_markers.filter { newMarker in
            !self.markers.contains { $0.id == newMarker.id }
          }
          self.markers.append(contentsOf: newMarkers)
        } else {
          self.markers = response.data.findSceneMarkers.scene_markers
        }
        self.totalMarkerCount = response.data.findSceneMarkers.count
        print(
          "✅ Loaded \(response.data.findSceneMarkers.scene_markers.count) markers for tags \(tagIds)"
        )
      }
    } catch {
      print("❌ Error loading markers by tags: \(error)")
      self.error = error
    }
    isLoading = false
  }

  func searchTags(query: String) async throws -> [StashScene.Tag] {
    isLoading = true
    defer { isLoading = false }

    // Use server-side search with the "q" parameter
    let graphQLQuery = """
      {
          "operationName": "FindTags",
          "variables": {
              "filter": {
                  "q": "\(query)",
                  "per_page": 100,
                  "sort": "name",
                  "direction": "ASC"
              },
              "tag_filter": {}
          },
          "query": "query FindTags($filter: FindFilterType, $tag_filter: TagFilterType) { findTags(filter: $filter, tag_filter: $tag_filter) { count tags { id name scene_count } } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = graphQLQuery.data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(TagSearchResponse.self, from: data)

    let tags = response.data.findTags.tags

    // Sort tags to prioritize exact matches and relevance
    let queryLower = query.lowercased()
    let sortedTags = tags.sorted { tag1, tag2 in
      let tag1Lower = tag1.name.lowercased()
      let tag2Lower = tag2.name.lowercased()

      // Exact match comes first
      if tag1Lower == queryLower && tag2Lower != queryLower {
        return true
      }
      if tag2Lower == queryLower && tag1Lower != queryLower {
        return false
      }

      // Then tags that start with the query
      if tag1Lower.hasPrefix(queryLower) && !tag2Lower.hasPrefix(queryLower) {
        return true
      }
      if tag2Lower.hasPrefix(queryLower) && !tag1Lower.hasPrefix(queryLower) {
        return false
      }

      // Finally, sort by scene count (most popular first)
      return (tag1.scene_count ?? 0) > (tag2.scene_count ?? 0)
    }

    print("✅ Tag search for '\(query)' found \(sortedTags.count) matching tags")
    print(
      "🏷️ First 10 matches: \(sortedTags.prefix(10).map { "\($0.name) (\($0.scene_count ?? 0) scenes)" })"
    )
    return sortedTags
  }

  func createTag(name: String) async throws -> StashScene.Tag {
    isLoading = true
    defer { isLoading = false }

    let query = """
      {
          "operationName": "TagCreate",
          "variables": {
              "input": {
                  "name": "\(name)"
              }
          },
          "query": "mutation TagCreate($input: TagCreateInput!) { tagCreate(input: $input) { id name scene_count image_count scene_marker_count } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = query.data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(TagCreateResponse.self, from: data)
    return response.data.tagCreate
  }

  // MARK: - Helper Methods

  private func performGraphQLRequest<T: Decodable>(query: String, variables: [String: Any]? = nil)
    async throws -> T
  {
    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    // Create the request body
    var requestBody: [String: Any] = [
      "query": query
    ]
    if let variables = variables {
      requestBody["variables"] = variables
    }

    // Convert request body to JSON data
    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
      throw URLError(.cannotParseResponse)
    }

    // Create and configure the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = jsonData

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        print("📡 GraphQL Response Status: \(httpResponse.statusCode)")
      }

      if let jsonString = String(data: data, encoding: .utf8) {
        print("📡 GraphQL Response: \(jsonString)")
      }

      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      print("❌ GraphQL Error: \(error)")
      throw error
    }
  }

  // Add a version of performGraphQLRequest that returns Data
  private func performGraphQLRequest(query: String, variables: [String: Any]? = nil) async throws
    -> Data
  {
    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    // Create the request body
    var requestBody: [String: Any] = [
      "query": query
    ]
    if let variables = variables {
      requestBody["variables"] = variables
    }

    // Convert request body to JSON data
    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
      throw URLError(.cannotParseResponse)
    }

    // Create and configure the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = jsonData

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        print("📡 GraphQL Response Status: \(httpResponse.statusCode)")
      }

      if let jsonString = String(data: data, encoding: .utf8) {
        print("📡 GraphQL Response: \(jsonString)")
      }

      return data
    } catch {
      print("❌ GraphQL Error: \(error)")
      throw error
    }
  }

  // Public method to execute GraphQL queries directly
  public func executeGraphQLQuery(_ query: String) async throws -> Data {
    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw StashAPIError.graphQLError("Invalid URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.httpBody = query.data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
  }

  private func performGraphQLRequest(query: String) async throws -> Data {
    return try await executeGraphQLQuery(query)
  }

  func fetchPerformerScenes(
    performerId: String, page: Int = 1, perPage: Int = 40, minimumScenes: Int? = nil,
    maximumScenes: Int? = nil, sort: String = "date", direction: String = "DESC",
    appendResults: Bool = false
  ) async {
    isLoading = true

    // Base performer filter
    // Make sure we're using the actual performer ID, not a different value
    print("🔍 Using performer ID: \(performerId) for fetch request")

    var sceneFilter = """
      "performers": {
          "modifier": "INCLUDES",
          "value": ["\(performerId)"]
      }
      """

    // Add scene count filter if needed
    if let min = minimumScenes {
      sceneFilter += """
        ,
        "scene_count": {
            "value": \(min),
            "modifier": "GREATER_THAN"
        }
        """
    } else if let max = maximumScenes {
      sceneFilter += """
        ,
        "scene_count": {
            "value": \(max),
            "modifier": "LESS_THAN"
        }
        """
    }

    let query = """
      {
          "operationName": "FindScenes",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": \(perPage),
                  "sort": "\(sort)",
                  "direction": "\(direction)"
              },
              "scene_filter": {
                  \(sceneFilter)
              }
          },
          "query": "query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) { findScenes(filter: $filter, scene_filter: $scene_filter) { count scenes { id title details paths { screenshot preview stream } files { size duration video_codec width height } performers { id name gender scene_count } tags { id name } rating100 } } }"
      }
      """

    print(
      "🔍 Performer scenes query page \(page) for performer \(performerId) (sort: \(sort), direction: \(direction))"
    )

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print("❌ Invalid URL for performer scenes")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")  // Add token auth
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue(
      "\(serverAddress)/performers/\(performerId)/scenes?sortby=date", forHTTPHeaderField: "Referer"
    )
    request.httpBody = query.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)

      // Debug response
      if let jsonString = String(data: data, encoding: .utf8) {
        print("📊 Performer scenes response: \(jsonString.prefix(200))...")
      }

      let decodedResponse = try JSONDecoder().decode(ScenesResponse.self, from: data)

      await MainActor.run {
        if !appendResults {
          self.scenes = decodedResponse.data.findScenes.scenes
          print(
            "✅ Loaded \(decodedResponse.data.findScenes.scenes.count) scenes for performer \(performerId) (page \(page))"
          )
        } else {
          // Filter out duplicates before appending
          let newScenes = decodedResponse.data.findScenes.scenes.filter { newScene in
            !self.scenes.contains { $0.id == newScene.id }
          }
          self.scenes.append(contentsOf: newScenes)
          print("✅ Added \(newScenes.count) new scenes for performer \(performerId) (page \(page))")
        }

        // Store the total count from the API
        self.totalSceneCount = decodedResponse.data.findScenes.count
        print("📊 Total scenes available: \(decodedResponse.data.findScenes.count)")
      }
    } catch {
      print("❌ Error loading performer scenes: \(error)")
      if let decodingError = error as? DecodingError {
        print("⚠️ Decoding error details: \(decodingError)")
      }
      self.error = error
    }

    isLoading = false
  }

  func fetchPerformerMarkers(performerId: String, page: Int = 1, perPage: Int = 20) async throws
    -> [SceneMarker]
  {
    isLoading = true

    // Generate a random seed for consistent random sorting within this query
    let randomSeed = Int.random(in: 0...999999)

    let query = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "page": \(page),
                  "per_page": \(perPage),
                  "sort": "random_\(randomSeed)",
                  "direction": "ASC"
              },
              "scene_marker_filter": {
                  "performers": {
                      "value": ["\(performerId)"],
                      "modifier": "INCLUDES_ALL"
                  }
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { ...SceneMarkerData __typename } __typename } } fragment SceneMarkerData on SceneMarker { id title seconds end_seconds stream preview screenshot scene { ...SceneMarkerSceneData __typename } primary_tag { id name __typename } tags { id name __typename } __typename } fragment SceneMarkerSceneData on Scene { id title files { width height path __typename } performers { id name image_path __typename } __typename }"
      }
      """

    print("🔍 Performer marker query page \(page) for performer \(performerId)")

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print("❌ Invalid URL for performer markers")
      isLoading = false
      throw StashAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")  // Add token auth
    request.setValue(serverAddress, forHTTPHeaderField: "Origin")
    request.setValue(
      "nc_sameSiteCookielax=true; nc_sameSiteCookiestrict=true", forHTTPHeaderField: "Cookie")
    request.setValue("\(serverAddress)/scenes/markers", forHTTPHeaderField: "Referer")
    request.httpBody = query.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)

      // Debug response
      if let jsonString = String(data: data, encoding: .utf8) {
        print("📊 Performer markers response: \(jsonString.prefix(200))...")
      }

      let response = try JSONDecoder().decode(SceneMarkersResponse.self, from: data)

      await MainActor.run {
        if page == 1 {
          self.markers = response.data.findSceneMarkers.scene_markers
        } else {
          self.markers.append(contentsOf: response.data.findSceneMarkers.scene_markers)
        }
        print(
          "✅ Loaded \(response.data.findSceneMarkers.scene_markers.count) markers for performer \(performerId) (page \(page))"
        )
      }

      isLoading = false
      return response.data.findSceneMarkers.scene_markers

    } catch {
      print("❌ Error loading performer markers: \(error)")
      if let decodingError = error as? DecodingError {
        print("⚠️ Decoding error details: \(decodingError)")
      }
      self.error = error
      isLoading = false
      throw error
    }
  }

  func fetchPerformerDetails(performerId: String) async {
    isLoading = true

    let query = """
      {
          "operationName": "FindPerformer",
          "variables": {
              "id": "\(performerId)"
          },
          "query": "query FindPerformer($id: ID!) { findPerformer(id: $id) { id name disambiguation urls gender birthdate ethnicity country eye_color height_cm measurements fake_tits career_length tattoos piercings alias_list favorite ignore_auto_tag image_path scene_count image_count gallery_count rating100 details hair_color } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print(" Invalid URL for performer details")
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.httpBody = query.data(using: .utf8)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let response = try JSONDecoder().decode(PerformerDetailsResponse.self, from: data)
      // Store the performer details if needed
      print(" Loaded performer details: \(response.data.findPerformer.name)")
    } catch {
      print(" Error loading performer details: \(error)")
      self.error = error
    }

    isLoading = false
  }

  // MARK: - Thumbnail Methods

  func getThumbnailURLForScene(sceneID: String, seconds: Double) -> URL? {
    // Use the static helper method to avoid duplicate code
    return VideoPlayerUtility.getThumbnailURL(forSceneID: sceneID, seconds: seconds)
  }

  func getSpriteURLForScene(sceneID: String) -> URL? {
    // Use the static helper method to avoid duplicate code
    return VideoPlayerUtility.getSpriteURL(forSceneID: sceneID)
  }

  func getVTTURLForScene(sceneID: String) -> URL? {
    // Use the static helper method to avoid duplicate code
    return VideoPlayerUtility.getVTTURL(forSceneID: sceneID)
  }

  func fetchScene(byID id: String) async throws -> StashScene? {
    let query = """
      query FindScene($id: ID!) {
          findScene(id: $id) {
              id
              title
              details
              url
              date
              rating100
              organized
              o_counter
              paths {
                  screenshot
                  preview
                  stream
                  webp
                  vtt
                  sprite
                  funscript
                  interactive_heatmap
              }
              files {
                  size
                  duration
                  video_codec
                  width
                  height
              }
              performers {
                  id
                  name
              }
              tags {
                  id
                  name
              }
              studio {
                  id
                  name
              }
              stash_ids {
                  endpoint
                  stash_id
              }
              created_at
              updated_at
          }
      }
      """

    let variables = ["id": id]

    do {
      let response: GraphQLResponse<SceneResponse> = try await performGraphQLRequest(
        query: query, variables: variables)
      if let errors = response.errors {
        print("❌ GraphQL Errors: \(errors)")
        throw StashAPIError.graphQLError(errors.map { $0.message }.joined(separator: ", "))
      }
      return response.data.findScene
    } catch {
      print("❌ Error fetching scene: \(error)")
      throw error
    }
  }

  struct TagsResponse: Codable {
    let data: TagData

    struct TagData: Codable {
      let findTags: TagResults

      struct TagResults: Codable {
        let count: Int
        let tags: [StashScene.Tag]
      }
    }
  }

  /// Fetch all tags that are used by markers (have scene_marker_count > 0)
  func fetchMarkerTags() async throws -> [StashScene.Tag] {
    let query = """
      {
          "operationName": "FindTags",
          "variables": {
              "filter": {
                  "page": 1,
                  "per_page": -1,
                  "sort": "name",
                  "direction": "ASC"
              }
          },
          "query": "query FindTags($filter: FindFilterType) { findTags(filter: $filter) { count tags { id name scene_marker_count } } }"
      }
      """

    struct MarkerTagsResponse: Decodable {
      let data: TagData

      struct TagData: Decodable {
        let findTags: TagsPayload

        struct TagsPayload: Decodable {
          let tags: [Tag]

          struct Tag: Decodable {
            let id: String
            let name: String
            let scene_marker_count: Int?
          }
        }
      }
    }

    let data = try await performGraphQLRequest(query: query)
    let response = try JSONDecoder().decode(MarkerTagsResponse.self, from: data)

    // Filter to only include tags that have markers (scene_marker_count > 0)
    let markerTags = response.data.findTags.tags
      .filter { ($0.scene_marker_count ?? 0) > 0 }
      .map { tag in
        StashScene.Tag(
          id: tag.id,
          name: tag.name,
          scene_count: 0,  // Not relevant for marker tags
          image_count: 0,  // Not relevant for marker tags
          scene_marker_count: tag.scene_marker_count
        )
      }

    print("📊 Fetched \(markerTags.count) tags that are used by markers")
    return markerTags
  }

  func fetchTags() async throws -> [StashScene.Tag] {
    isLoading = true
    defer { isLoading = false }

    let graphQLQuery = """
      {
          "operationName": "FindTags",
          "variables": {
              "filter": {
                  "per_page": 1000,
                  "sort": "name",
                  "direction": "ASC"
              }
          },
          "query": "query FindTags($filter: FindFilterType) { findTags(filter: $filter) { count tags { id name scene_count } } }"
      }
      """

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = graphQLQuery.data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    // Removed full response logging for performance
    let response = try JSONDecoder().decode(TagsResponse.self, from: data)
    return response.data.findTags.tags
  }

  // Add findScenes method to support filtering by tags
  func findScenes(filter: SceneFilterType, page: Int = 1, perPage: Int = 20) async throws -> (
    scenes: [StashScene], count: Int
  ) {
    // Create tag IDs filter if tags are provided
    var tagIDs: String?
    if let tags = filter.tags, !tags.isEmpty {
      tagIDs = "[" + tags.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
      print("🏷️ Using tag filter with IDs: \(tagIDs!)")
    }

    // Create performer IDs filter if performers are provided
    var performerIDs: String?
    if let performers = filter.performers, !performers.isEmpty {
      performerIDs = "[" + performers.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }

    // Create studio IDs filter if studios are provided
    var studioIDs: String?
    if let studios = filter.studios, !studios.isEmpty {
      studioIDs = "[" + studios.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }

    let query = """
      {
        "operationName": "FindTaggedScenes",
        "variables": {
          "filter": {
            "page": \(page),
            "per_page": \(perPage)
            \(filter.searchTerm != nil ? ", \"q\": \"\(filter.searchTerm!)\"" : "")
          },
          "scene_filter": {
            "tags": {
              "value": \(tagIDs ?? "null"),
              "modifier": "INCLUDES"
            }
            \(performerIDs != nil ? ", \"performers\": {\"value\": \(performerIDs!), \"modifier\": \"INCLUDES\"}" : "")
            \(studioIDs != nil ? ", \"studios\": {\"value\": \(studioIDs!), \"modifier\": \"INCLUDES\"}" : "")
          }
        },
        "query": "query FindTaggedScenes($filter: FindFilterType, $scene_filter: SceneFilterType) { findScenes(filter: $filter, scene_filter: $scene_filter) { count scenes { id title details date rating100 o_counter paths { screenshot stream preview } tags { id name } performers { id name image_path } studio { id name } files { width height video_codec duration } } } }"
      }
      """

    struct FindScenesResponse: Decodable {
      struct Data: Decodable {
        struct FindScenes: Decodable {
          let count: Int
          let scenes: [StashScene]
        }
        let findScenes: FindScenes
      }
      let data: Data
    }

    do {
      print("📤 Sending GraphQL query for tag filter: \(query)")
      let data = try await performGraphQLRequest(query: query)

      // Debug the response data
      if let jsonString = String(data: data, encoding: .utf8) {
        print("📥 Received GraphQL response: \(jsonString.prefix(500))...")
      }

      let decoder = JSONDecoder()
      do {
        let response = try decoder.decode(FindScenesResponse.self, from: data)
        print(
          "✅ Successfully decoded response with \(response.data.findScenes.scenes.count) scenes")
        return (scenes: response.data.findScenes.scenes, count: response.data.findScenes.count)
      } catch let decodingError {
        print("❌ Decoding error: \(decodingError)")
        if let jsonString = String(data: data, encoding: .utf8) {
          print("📥 Failed to decode: \(jsonString)")
        }
        throw decodingError
      }
    } catch {
      print("❌ Error fetching scenes: \(error)")
      throw error
    }
  }

  /// Fetches statistics from Stash server
  public func fetchStats() async throws -> StashStats {
    do {
      let query = """
        query {
          stats {
            scene_count
            scenes_size
            scenes_duration
            image_count
            images_size
            gallery_count
            performer_count
            studio_count
            movie_count
            tag_count
          }
        }
        """

      let response: GraphQLResponse<StatsDataResponse> = try await send(query: query)

      // Check for errors in the response
      if let errors = response.errors, !errors.isEmpty {
        let errorMessages = errors.map { $0.message }.joined(separator: ", ")
        throw StashAPIError.graphQLError(errorMessages)
      }

      DispatchQueue.main.async {
        self.connectionStatus = .connected
      }

      return response.data.stats
    } catch {
      DispatchQueue.main.async {
        self.connectionStatus = .failed(error)
      }

      NSLog("Error fetching stats: \(error)")
      throw error
    }
  }

  /// Checks if the Stash server is reachable and if the API key is valid
  public func checkServerConnection() async throws {
    print("🔄 Checking server connection to \(serverAddress)")

    guard let url = URL(string: "\(serverAddress)/graphql") else {
      print("❌ Invalid server URL")
      throw StashAPIError.invalidURL
    }

    // Create a simple query to check server status - using the same one from StashConnectionTest
    let query = """
      {
          "operationName": "FindPerformers",
          "variables": {
              "filter": {
                  "page": 1,
                  "per_page": 1,
                  "sort": "name",
                  "direction": "ASC"
              }
          },
          "query": "query FindPerformers($filter: FindFilterType) { findPerformers(filter: $filter) { count performers { id name } } }"
      }
      """

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Add both authentication methods to ensure compatibility
    request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    request.httpBody = query.data(using: .utf8)

    do {
      print("📤 Sending connection check request...")
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        print("❌ Invalid response type")
        throw StashAPIError.invalidResponse
      }

      print("📡 Server responded with status code: \(httpResponse.statusCode)")

      switch httpResponse.statusCode {
      case 200:
        guard !data.isEmpty else {
          print("❌ Empty response data")
          throw StashAPIError.emptyResponse
        }

        // Try to decode the response
        if let jsonString = String(data: data, encoding: .utf8) {
          print("📥 Response: \(jsonString.prefix(200))...")
        }

        do {
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

          // Check if we got a data field
          guard let dataField = json?["data"] as? [String: Any] else {
            print("❌ Response missing data field")
            throw StashAPIError.invalidData("Response missing data field")
          }

          // Check if we have performers data
          guard let findPerformers = dataField["findPerformers"] as? [String: Any] else {
            print("❌ Response missing performers data")
            throw StashAPIError.invalidData("Response missing performers data")
          }

          print("✅ Server connection successful")
          print("📊 Performers data: \(findPerformers)")
        } catch {
          print("❌ Failed to parse response: \(error)")
          throw StashAPIError.decodingError(error)
        }

      case 401, 403:
        print("🔒 Authentication failed")
        throw StashAPIError.authenticationFailed

      case 404:
        print("❌ Server endpoint not found")
        throw StashAPIError.connectionFailed("Server endpoint not found")

      case 500...599:
        print("❌ Server error: \(httpResponse.statusCode)")
        throw StashAPIError.serverError(httpResponse.statusCode)

      default:
        print("❌ Unexpected status code: \(httpResponse.statusCode)")
        throw StashAPIError.invalidResponse
      }
    } catch let error as StashAPIError {
      print("❌ StashAPI Error: \(error.localizedDescription)")
      throw error
    } catch {
      print("❌ Network Error: \(error.localizedDescription)")
      throw StashAPIError.networkError(error)
    }
  }

  // Update DLNA settings in Stash
  func updateDLNASettings(enabled: Bool) async throws -> Bool {
    let query = """
      mutation {
        configureDLNA(input: {
          enabled: \(enabled)
        }) {
          enabled
        }
      }
      """

    struct DLNAUpdateResponse: Decodable {
      struct Data: Decodable {
        struct ConfigureDLNA: Decodable {
          let enabled: Bool
        }
        let configureDLNA: ConfigureDLNA
      }
      let data: Data
    }

    do {
      let data = try await performGraphQLRequest(query: query)
      let decoder = JSONDecoder()
      let response = try decoder.decode(DLNAUpdateResponse.self, from: data)
      return response.data.configureDLNA.enabled
    } catch {
      print("❌ Error updating DLNA settings: \(error)")
      throw error
    }
  }
}

// MARK: - Data Models

// StashStats model for stats endpoint
struct StashStats: Codable {
  let scene_count: Int
  let scenes_size: Int64
  let scenes_duration: Double
  let image_count: Int
  let images_size: Int64
  let gallery_count: Int
  let performer_count: Int
  let studio_count: Int
  let movie_count: Int
  let tag_count: Int
}

extension StashAPI {
  // MARK: - Marker Search Methods

  /// Search markers by suffix pattern (e.g., "_ai", "_anal")
  func searchMarkersBySuffix(suffix: String) async {
    print("🔍 Searching markers with suffix pattern: '_\(suffix)'")
    isLoading = true

    let query = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "q": "",
                  "page": 1,
                  "per_page": 500,
                  "sort": "created_at",
                  "direction": "DESC"
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType) { findSceneMarkers(filter: $filter) { count scene_markers { id title seconds end_seconds stream preview screenshot scene { id title files { width height path } performers { id name image_path } } primary_tag { id name } tags { id name } } } }"
      }
      """

    do {
      let data = try await executeGraphQLQuery(query)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let scene_markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)

      // Filter markers where primary tag ends with the suffix
      let filteredMarkers = response.data.findSceneMarkers.scene_markers.filter { marker in
        if let primaryTag = marker.primary_tag {
          return primaryTag.name.lowercased().hasSuffix("_\(suffix.lowercased())")
        }
        return false
      }

      await MainActor.run {
        self.markers = filteredMarkers
        self.totalMarkerCount = filteredMarkers.count
        print("✅ Found \(filteredMarkers.count) markers with suffix '_\(suffix)'")
      }
    } catch {
      print("❌ Error searching markers by suffix: \(error)")
      self.error = error
    }

    isLoading = false
  }

  /// Search markers by tag name
  func searchMarkersByTagName(tagName: String) async {
    print("🏷️ Searching markers by tag name: '\(tagName)'")
    isLoading = true

    // First, find tags that match the name
    let searchQuery = """
      {
          "operationName": "FindTags",
          "variables": {
              "filter": {
                  "q": "\(tagName)",
                  "page": 1,
                  "per_page": 20,
                  "sort": "name",
                  "direction": "ASC"
              }
          },
          "query": "query FindTags($filter: FindFilterType) { findTags(filter: $filter) { count tags { id name scene_marker_count } } }"
      }
      """

    do {
      let data = try await executeGraphQLQuery(searchQuery)

      struct TagsResponseData: Decodable {
        let data: TagData

        struct TagData: Decodable {
          let findTags: TagsPayload

          struct TagsPayload: Decodable {
            let count: Int
            let tags: [Tag]

            struct Tag: Decodable {
              let id: String
              let name: String
              let scene_marker_count: Int?
            }
          }
        }
      }

      let response = try JSONDecoder().decode(TagsResponseData.self, from: data)

      // Find exact match or closest match
      if let matchingTag = response.data.findTags.tags.first(where: {
        $0.name.lowercased() == tagName.lowercased()
      }) {
        // Fetch markers for this tag
        await fetchMarkersByTag(tagId: matchingTag.id, page: 1, appendResults: false, perPage: 500)
      } else {
        // No exact match found
        await MainActor.run {
          self.markers = []
          self.totalMarkerCount = 0
          print("⚠️ No tag found matching: '\(tagName)'")
        }
      }
    } catch {
      print("❌ Error searching markers by tag name: \(error)")
      self.error = error
    }

    isLoading = false
  }

  /// Update markers from search query
  func updateMarkersFromSearch(query: String, page: Int = 1, appendResults: Bool = false) async {
    print("🔍 Searching markers with query: '\(query)' (page \(page))")
    isLoading = true

    let searchQuery = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "q": "\(query)",
                  "page": \(page),
                  "per_page": 500,
                  "sort": "created_at",
                  "direction": "DESC"
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType) { findSceneMarkers(filter: $filter) { count scene_markers { id title seconds end_seconds stream preview screenshot scene { id title files { width height path } performers { id name image_path } } primary_tag { id name } tags { id name } } } }"
      }
      """

    do {
      let data = try await executeGraphQLQuery(searchQuery)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let scene_markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)

      await MainActor.run {
        if appendResults {
          self.markers.append(contentsOf: response.data.findSceneMarkers.scene_markers)
        } else {
          self.markers = response.data.findSceneMarkers.scene_markers
        }
        self.totalMarkerCount = response.data.findSceneMarkers.count
        print(
          "✅ Found \(response.data.findSceneMarkers.scene_markers.count) markers for query: '\(query)'"
        )
      }
    } catch {
      print("❌ Error searching markers: \(error)")
      self.error = error
    }

    isLoading = false
  }

  /// Update fetchMarkersByTag to support perPage parameter
  func fetchMarkersByTag(
    tagId: String, page: Int = 1, appendResults: Bool = false, perPage: Int = 25
  ) async {
    isLoading = true

    let query = """
      {
          "operationName": "FindSceneMarkers",
          "variables": {
              "filter": {
                  "q": "",
                  "page": \(page),
                  "per_page": \(perPage),
                  "sort": "created_at",
                  "direction": "DESC"
              },
              "scene_marker_filter": {
                  "tags": {
                      "value": ["\(tagId)"],
                      "modifier": "INCLUDES_ALL"
                  }
              }
          },
          "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count scene_markers { id title seconds end_seconds stream preview screenshot scene { id title files { width height path } performers { id name image_path } } primary_tag { id name } tags { id name } } } }"
      }
      """

    do {
      let data = try await executeGraphQLQuery(query)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let scene_markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)

      await MainActor.run {
        if appendResults {
          self.markers.append(contentsOf: response.data.findSceneMarkers.scene_markers)
        } else {
          self.markers = response.data.findSceneMarkers.scene_markers
        }
        self.totalMarkerCount = response.data.findSceneMarkers.count
        print(
          "✅ Loaded \(response.data.findSceneMarkers.scene_markers.count) markers for tag \(tagId)")
      }
    } catch {
      print("❌ Error loading markers by tag: \(error)")
      self.error = error
    }

    isLoading = false
  }
}

// MARK: - GraphQL Models

/// Stats data response from the Stash API
struct StatsDataResponse: Decodable {
  let stats: StashStats
}

/// Extension to add the send method for GraphQL queries
extension StashAPI {
  func send<T: Decodable>(query: String) async throws -> GraphQLResponse<T> {
    // Use the existing performGraphQLRequest method
    return try await performGraphQLRequest(query: query)
  }
}
