import AVKit
import SwiftUI
import UIKit

class VideoPlayerUtility {
  // Local API key - made public for direct access
  public static let apiKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

  // Server address - made public for direct access
  public static let serverAddress = "http://192.168.86.100:9999"

  // Check if thumbnails should be loaded immediately or deferred for VPN
  public static var shouldDeferThumbnails: Bool {
    // Simple VPN detection without MainActor dependency
    return detectVPNSync()
  }

  // Simple synchronous VPN detection
  private static func detectVPNSync() -> Bool {
    // Check if default route goes through a VPN interface
    if let defaultInterface = getDefaultRouteInterface() {
      // If default route goes through utun interface, check if it has an IP address
      if defaultInterface.hasPrefix("utun") {
        return checkUtunInterfaceForVPN(defaultInterface)
      }

      // Check for other VPN interface types
      let vpnPrefixes = ["tun", "ppp", "ipsec", "wg"]
      for prefix in vpnPrefixes {
        if defaultInterface.hasPrefix(prefix) {
          return true
        }
      }

      // Check for VPN-specific names
      if defaultInterface.contains("vpn") || defaultInterface.contains("wireguard") {
        return true
      }
    }

    return false
  }

  private static func getDefaultRouteInterface() -> String? {
    // Use a different approach to get default route interface
    // Check if any utun interface has both an IPv4 address and default routing behavior
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return nil
    }

    defer { freeifaddrs(ifaddr) }

    var utunInterfaces: [String] = []
    var addr: UnsafeMutablePointer<ifaddrs>? = firstAddr

    // Collect utun interfaces that have IPv4 addresses
    while let currentAddr = addr {
      let name = String(cString: currentAddr.pointee.ifa_name)

      if name.hasPrefix("utun") {
        // Check if this interface has an IPv4 address
        if let sockaddr = currentAddr.pointee.ifa_addr,
          sockaddr.pointee.sa_family == UInt8(AF_INET) {
          utunInterfaces.append(name)
        }
      }

      addr = currentAddr.pointee.ifa_next
    }

    // Return the first utun interface with an IPv4 address
    // This is likely the VPN interface if it exists
    return utunInterfaces.first
  }

  private static func checkUtunInterfaceForVPN(_ interfaceName: String) -> Bool {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return false
    }

    defer { freeifaddrs(ifaddr) }

    var addr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let currentAddr = addr {
      let name = String(cString: currentAddr.pointee.ifa_name)

      if name == interfaceName {
        // Check if this interface has an IPv4 address (indicates active VPN)
        if let sockaddr = currentAddr.pointee.ifa_addr,
          sockaddr.pointee.sa_family == UInt8(AF_INET) {
          return true
        }
      }

      addr = currentAddr.pointee.ifa_next
    }

    return false
  }

  // Public URL helpers for direct access from other classes without StashAPI dependency
  // This avoids MainActor isolation issues

  // VPN-optimized thumbnail URL - skips complex lookups if on VPN
  public static func getOptimizedThumbnailURL(forSceneID id: String, seconds: Double) -> URL? {
    if detectVPNSync() {
      // Use simple thumbnail URL for VPN to avoid additional handshakes
      return getSimpleThumbnailURL(forSceneID: id, seconds: seconds)
    } else {
      // Use full-featured thumbnail URL for local network
      return getThumbnailURL(forSceneID: id, seconds: seconds)
    }
  }

  // Simple thumbnail URL without complex API lookups
  private static func getSimpleThumbnailURL(forSceneID id: String, seconds: Double) -> URL? {
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)/screenshot") else {
      return nil
    }

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "t", value: String(format: "%.2f", seconds)))
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    components.queryItems = queryItems
    return components.url
  }

  // Get thumbnail URL for a specific time
  public static func getThumbnailURL(forSceneID id: String, seconds: Double) -> URL? {
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)/screenshot") else {
      return nil
    }

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "t", value: String(format: "%.2f", seconds)))
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    components.queryItems = queryItems
    return components.url
  }

  // VPN-optimized VTT URL - defers complex lookups if on VPN
  public static func getOptimizedVTTURL(forSceneID id: String) -> URL? {
    if detectVPNSync() {
      // Skip complex VTT lookups for VPN - return nil to defer loading
      print("🌐 VPN detected - deferring VTT thumbnail loading for better performance")
      return nil
    } else {
      // Use full VTT lookup for local network
      return getVTTURL(forSceneID: id)
    }
  }

  // Get VTT URL (for thumbnail metadata)
  // Based on actual inspection of Stash's VTT URL format
  public static func getVTTURL(forSceneID id: String) -> URL? {
    // First try using the fingerprint/oshash if available
    // Try to get the scene file info to extract the oshash
    let fileInfoUrl = createURL(path: "/scene/\(id)/file", includeApiKey: true)

    // Check if we can determine the oshash for this scene synchronously
    if let fileInfoUrl = fileInfoUrl,
      let data = try? Data(contentsOf: fileInfoUrl),
      let jsonString = String(data: data, encoding: .utf8),
      let jsonData = jsonString.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
      let files = json["files"] as? [[String: Any]],
      let firstFile = files.first,
      let fingerprints = firstFile["fingerprints"] as? [[String: Any]] {
      // Look for oshash fingerprint
      for fingerprint in fingerprints {
        if let type = fingerprint["type"] as? String,
          type == "oshash",
          let oshash = fingerprint["value"] as? String {
          print("✅ Found oshash fingerprint: \(oshash)")

          // Use the oshash for the VTT URL
          guard
            var components = URLComponents(string: "\(serverAddress)/scene/\(oshash)_thumbs.vtt")
          else {
            continue
          }

          // Add API key
          var queryItems = [URLQueryItem]()
          queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

          components.queryItems = queryItems
          print("🔑 Created VTT URL with oshash: \(components.url?.absoluteString ?? "nil")")
          return components.url
        }
      }
    }

    // Fetch the oshash dynamically from the scene endpoint if we don't have it
    print("🔍 No oshash found in fingerprints for VTT, attempting to fetch it directly")

    // Make a synchronous API call to get the scene details which should include the oshash
    if let sceneUrl = createURL(path: "/graphql", includeApiKey: true),
      let request = try? JSONSerialization.data(withJSONObject: [
        "query":
          "query FindScene($id: ID!) { findScene(id: $id) { files { fingerprints { type value } } } }",
        "variables": ["id": id]
      ]) {
      var urlRequest = URLRequest(url: sceneUrl)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      urlRequest.httpBody = request

      // Use synchronous network request since we're in a synchronous context
      let semaphore = DispatchSemaphore(value: 0)
      var responseData: Data?

      URLSession.shared.dataTask(with: urlRequest) { data, _, _ in
        responseData = data
        semaphore.signal()
      }.resume()

      // Wait for the request to complete with a reasonable timeout
      _ = semaphore.wait(timeout: .now() + 5)

      if let data = responseData,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let dataField = json["data"] as? [String: Any],
        let scene = dataField["findScene"] as? [String: Any],
        let files = scene["files"] as? [[String: Any]],
        let firstFile = files.first,
        let fingerprints = firstFile["fingerprints"] as? [[String: Any]] {
        // Look for oshash fingerprint
        for fingerprint in fingerprints {
          if let type = fingerprint["type"] as? String, type == "oshash",
            let oshash = fingerprint["value"] as? String {
            print("✅ Found oshash fingerprint via API for VTT: \(oshash)")

            // Use the oshash for the VTT URL
            guard
              var components = URLComponents(string: "\(serverAddress)/scene/\(oshash)_thumbs.vtt")
            else {
              continue
            }

            // Add API key
            var queryItems = [URLQueryItem]()
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

            components.queryItems = queryItems
            print(
              "🔑 Created VTT URL with fetched oshash: \(components.url?.absoluteString ?? "nil")")
            return components.url
          }
        }
      }
    }

    // If we still don't have an oshash, use the ID directly in the required format
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)_thumbs.vtt") else {
      return nil
    }

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    components.queryItems = queryItems
    print(
      "🔑 Created VTT URL with original ID in oshash format: \(components.url?.absoluteString ?? "nil")"
    )
    return components.url
  }

  // Async version that can check local files
  public static func getVTTURLAsync(forSceneID id: String) async -> URL? {
    // First try the mounted volume path - this is a local file access and will be faster
    let fileInfoUrl = createURL(path: "/scene/\(id)/file", includeApiKey: true)

    if let url = fileInfoUrl {
      do {
        let request = createAuthenticatedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
          let jsonString = String(data: data, encoding: .utf8),
          let jsonData = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let files = json["files"] as? [[String: Any]],
          let firstFile = files.first,
          let oshash = firstFile["oshash"] as? String {
          print("✅ Found oshash for local VTT access: \(oshash)")

          // Try the locally mounted path
          let localPath = "/Volumes/vtt/\(oshash)_thumbs.vtt"
          let localUrl = URL(fileURLWithPath: localPath)

          // Check if file exists
          let fileManager = FileManager.default
          if fileManager.fileExists(atPath: localPath) {
            print("✅ Found VTT file at mounted location: \(localPath)")
            return localUrl
          } else {
            print("❌ Local VTT file not found at: \(localPath)")
          }
        }
      } catch {
        print("❌ Error looking up file info for local VTT: \(error)")
      }
    }

    // Fall back to server URL
    return getVTTURL(forSceneID: id)
  }

  // Alternative VTT URL in case the primary format doesn't work
  public static func getAlternativeVTTURL(forSceneID id: String) -> URL? {
    // Try several alternative formats to increase chances of finding the right one

    // Format 1: /scene/{id}/vtt
    if let url = createURL(path: "/scene/\(id)/vtt", includeApiKey: true) {
      print("🔑 Trying alternative VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 2: /scene/{id}/sprite/vtt
    if let url = createURL(path: "/scene/\(id)/sprite/vtt", includeApiKey: true) {
      print("🔑 Trying alternative VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 3: /scene/{id}/thumbs.vtt (without underscore)
    if let url = createURL(path: "/scene/\(id)/thumbs.vtt", includeApiKey: true) {
      print("🔑 Trying alternative VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 4: /scene/{id}/screenshot/vtt
    if let url = createURL(path: "/scene/\(id)/screenshot/vtt", includeApiKey: true) {
      print("🔑 Trying alternative VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 5: /scene/{id}/vtt/thumbnails
    if let url = createURL(path: "/scene/\(id)/vtt/thumbnails", includeApiKey: true) {
      print("🔑 Trying alternative VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 6: Access generated VTT files via API
    if let url = createURL(path: "/scene/\(id)/file", includeApiKey: true) {
      print("🔑 Trying to get file info via API for scene: \(id)")

      // Create a task to fetch the scene file info to find the oshash
      Task {
        do {
          let fileInfoUrl = url
          let fileInfoRequest = createAuthenticatedRequest(url: fileInfoUrl)
          let (data, _) = try await URLSession.shared.data(for: fileInfoRequest)

          if let jsonString = String(data: data, encoding: .utf8),
            let jsonData = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let files = json["files"] as? [[String: Any]],
            let firstFile = files.first,
            let oshash = firstFile["oshash"] as? String {
            print("✅ Found oshash: \(oshash) for scene: \(id)")

            // Try with the oshash from the file
            if let vttUrl = createURL(
              path: "/.stash/generated/vtt/\(oshash)_thumbs.vtt", includeApiKey: true) {
              print("🔑 Trying VTT with oshash: \(vttUrl.absoluteString)")
            }

            // Also try with full path
            if let fullPathUrl = URL(
              string: "\(serverAddress)/Users/mediaserver/.stash/generated/vtt/\(oshash)_thumbs.vtt"
            ) {
              print("🔑 Trying full path with oshash: \(fullPathUrl.absoluteString)")
            }
          }
        } catch {
          print("❌ Error fetching file info: \(error)")
        }
      }
    }

    // Format 7: Try direct paths with arbitrary ID (scene ID may not be oshash)
    if let url = createURL(path: "/.stash/generated/vtt/\(id)_thumbs.vtt", includeApiKey: true) {
      print("🔑 Trying direct generated VTT URL: \(url.absoluteString)")
      return url
    }

    // Format 8: Try using the full path
    if let url = URL(
      string: "\(serverAddress)/Users/mediaserver/.stash/generated/vtt/\(id)_thumbs.vtt") {
      print("🔑 Trying full path VTT URL: \(url.absoluteString)")

      // Create a modified URL with API key
      guard var components = URLComponents(string: url.absoluteString) else {
        return url
      }

      var queryItems = [URLQueryItem]()
      queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
      components.queryItems = queryItems

      return components.url ?? url
    }

    print("⚠️ No alternative VTT URLs found for scene ID: \(id)")
    return nil
  }

  // Helper method to create a URL with API key
  public static func createURL(path: String, includeApiKey: Bool = true) -> URL? {
    guard var components = URLComponents(string: "\(serverAddress)\(path)") else {
      return nil
    }

    if includeApiKey {
      var queryItems = [URLQueryItem]()
      queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
      components.queryItems = queryItems
    }

    return components.url
  }

  // Helper method to add API key to an existing URL
  public static func addApiKeyToUrl(_ url: URL) -> URL? {
    guard var components = URLComponents(string: url.absoluteString) else {
      return url
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
    components.queryItems = queryItems

    return components.url ?? url
  }

  // Create an authenticated request for VTT or sprite files
  public static func createAuthenticatedRequest(url: URL) -> URLRequest {
    var request = URLRequest(url: url)

    // Add API key as Authorization header to ensure authentication
    request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Add standard headers
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

    return request
  }

  // Get sprite sheet URL (for thumbnail images)
  // Based on actual inspection of Stash's sprite URL format
  public static func getSpriteURL(forSceneID id: String) -> URL? {
    // First try using the fingerprint/oshash if available
    // Try to get the scene file info to extract the oshash
    let fileInfoUrl = createURL(path: "/scene/\(id)/file", includeApiKey: true)

    // Check if we can determine the oshash for this scene synchronously
    if let fileInfoUrl = fileInfoUrl,
      let data = try? Data(contentsOf: fileInfoUrl),
      let jsonString = String(data: data, encoding: .utf8),
      let jsonData = jsonString.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
      let files = json["files"] as? [[String: Any]],
      let firstFile = files.first,
      let fingerprints = firstFile["fingerprints"] as? [[String: Any]] {
      // Look for oshash fingerprint
      for fingerprint in fingerprints {
        if let type = fingerprint["type"] as? String,
          type == "oshash",
          let oshash = fingerprint["value"] as? String {
          print("✅ Found oshash fingerprint for sprite: \(oshash)")

          // Use the oshash for the sprite URL
          guard
            var components = URLComponents(string: "\(serverAddress)/scene/\(oshash)_sprite.jpg")
          else {
            continue
          }

          // Add API key
          var queryItems = [URLQueryItem]()
          queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

          components.queryItems = queryItems
          print("🔑 Created sprite URL with oshash: \(components.url?.absoluteString ?? "nil")")
          return components.url
        }
      }
    }

    // Fetch the oshash dynamically from the scene endpoint if we don't have it
    print("🔍 No oshash found in fingerprints, attempting to fetch it directly")

    // Make a synchronous API call to get the scene details which should include the oshash
    if let sceneUrl = createURL(path: "/graphql", includeApiKey: true),
      let request = try? JSONSerialization.data(withJSONObject: [
        "query":
          "query FindScene($id: ID!) { findScene(id: $id) { files { fingerprints { type value } } } }",
        "variables": ["id": id]
      ]) {
      var urlRequest = URLRequest(url: sceneUrl)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      urlRequest.httpBody = request

      // Use synchronous network request since we're in a synchronous context
      let semaphore = DispatchSemaphore(value: 0)
      var responseData: Data?

      URLSession.shared.dataTask(with: urlRequest) { data, _, _ in
        responseData = data
        semaphore.signal()
      }.resume()

      // Wait for the request to complete with a reasonable timeout
      _ = semaphore.wait(timeout: .now() + 5)

      if let data = responseData,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let dataField = json["data"] as? [String: Any],
        let scene = dataField["findScene"] as? [String: Any],
        let files = scene["files"] as? [[String: Any]],
        let firstFile = files.first,
        let fingerprints = firstFile["fingerprints"] as? [[String: Any]] {
        // Look for oshash fingerprint
        for fingerprint in fingerprints {
          if let type = fingerprint["type"] as? String, type == "oshash",
            let oshash = fingerprint["value"] as? String {
            print("✅ Found oshash fingerprint via API: \(oshash)")

            // Use the oshash for the sprite URL
            guard
              var components = URLComponents(string: "\(serverAddress)/scene/\(oshash)_sprite.jpg")
            else {
              continue
            }

            // Add API key
            var queryItems = [URLQueryItem]()
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

            components.queryItems = queryItems
            print(
              "🔑 Created sprite URL with fetched oshash: \(components.url?.absoluteString ?? "nil")"
            )
            return components.url
          }
        }
      }
    }

    // If we still don't have an oshash, use the ID directly in the required format
    guard var components = URLComponents(string: "\(serverAddress)/scene/\(id)_sprite.jpg") else {
      return nil
    }

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "apikey", value: apiKey))

    components.queryItems = queryItems
    print(
      "🔑 Created sprite URL with original ID in oshash format: \(components.url?.absoluteString ?? "nil")"
    )
    return components.url
  }

  // Async version that can check local files
  public static func getSpriteURLAsync(forSceneID id: String) async -> URL? {
    // First try the mounted volume path - this is a local file access and will be faster
    let fileInfoUrl = createURL(path: "/scene/\(id)/file", includeApiKey: true)

    if let url = fileInfoUrl {
      do {
        let request = createAuthenticatedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
          let jsonString = String(data: data, encoding: .utf8),
          let jsonData = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let files = json["files"] as? [[String: Any]],
          let firstFile = files.first,
          let oshash = firstFile["oshash"] as? String {
          print("✅ Found oshash for local sprite access: \(oshash)")

          // Try the locally mounted path
          let localPath = "/Volumes/vtt/\(oshash)_sprite.jpg"
          let localUrl = URL(fileURLWithPath: localPath)

          // Check if file exists
          let fileManager = FileManager.default
          if fileManager.fileExists(atPath: localPath) {
            print("✅ Found sprite file at mounted location: \(localPath)")
            return localUrl
          } else {
            print("❌ Local sprite file not found at: \(localPath)")
          }
        }
      } catch {
        print("❌ Error looking up file info for local sprite: \(error)")
      }
    }

    // Fall back to server URL
    return getSpriteURL(forSceneID: id)
  }

  // Fallback sprite URL in case the primary format doesn't work
  public static func getAlternativeSpriteURL(forSceneID id: String) -> URL? {
    // Try several alternative formats to increase chances of finding the right one

    // Format 1: /scene/{id}/sprite (.jpg is implied)
    if let url = createURL(path: "/scene/\(id)/sprite") {
      print("🔍 Trying sprite URL: \(url.absoluteString)")
      return url
    }

    // Format 2: /scene/{id}/sprite.jpg (explicit jpg)
    if let url = createURL(path: "/scene/\(id)/sprite.jpg") {
      print("🔍 Trying sprite URL: \(url.absoluteString)")
      return url
    }

    // Format 3: /scene/{id}/thumbnail/sprite
    if let url = createURL(path: "/scene/\(id)/thumbnail/sprite") {
      print("🔍 Trying sprite URL: \(url.absoluteString)")
      return url
    }

    // Format 4: /scene/{id}/preview/sprite
    if let url = createURL(path: "/scene/\(id)/preview/sprite") {
      print("🔍 Trying sprite URL: \(url.absoluteString)")
      return url
    }

    // Format 5: /scene/sprite/{id}.jpg
    if let url = createURL(path: "/scene/sprite/\(id).jpg") {
      print("🔍 Trying sprite URL: \(url.absoluteString)")
      return url
    }

    // Try to get oshash from file info endpoint
    if let fileInfoUrl = createURL(path: "/scene/\(id)/file", includeApiKey: true) {
      Task {
        do {
          // Create authenticated request
          let request = createAuthenticatedRequest(url: fileInfoUrl)
          let (data, _) = try await URLSession.shared.data(for: request)

          // Try to parse the JSON response
          if let jsonString = String(data: data, encoding: .utf8),
            let jsonData = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let files = json["files"] as? [[String: Any]],
            let firstFile = files.first,
            let oshash = firstFile["oshash"] as? String {
            print("✅ Found oshash: \(oshash) for sprite lookup")

            // Generate sprite URLs with oshash
            if let oshashUrl = createURL(
              path: "/.stash/generated/vtt/\(oshash)_sprite.jpg", includeApiKey: true) {
              print("🔍 Trying sprite URL with oshash: \(oshashUrl.absoluteString)")
            }

            if let fullPathUrl = URL(
              string: "\(serverAddress)/Users/mediaserver/.stash/generated/vtt/\(oshash)_sprite.jpg"
            ) {
              // Get components for potential query param additions if needed
              _ = URLComponents(string: fullPathUrl.absoluteString)
              print("🔍 Trying full path sprite URL with oshash: \(fullPathUrl.absoluteString)")
            }
          }
        } catch {
          print("❌ Error fetching file info for sprite oshash: \(error)")
        }
      }
    }

    return nil
  }

  // VTT Entry parser for manually extracting thumbnails if needed
  public struct VTTEntry {
    let startTime: Double
    let endTime: Double
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let spriteImage: String
  }

  // Parse VTT content directly from a string
  public static func parseVTTContent(_ content: String) -> [VTTEntry]? {
    // Print a small sample of the VTT content for debugging
    let previewLength = min(content.count, 200)
    let contentPreview = content.prefix(previewLength)
    print("🔍 VTT content preview: \(contentPreview)...")

    var entries: [VTTEntry] = []
    let lines = content.components(separatedBy: .newlines)
    var currentStartTime: Double?
    var currentEndTime: Double?

    print("🔍 Parsing \(lines.count) lines from VTT content")

    for (index, line) in lines.enumerated() {
      // Skip WEBVTT header and empty lines
      if line.contains("WEBVTT") || line.isEmpty {
        continue
      }

      // Parse time range (e.g., "00:00:10.000 --> 00:00:20.000")
      if line.contains("-->") {
        let times = line.components(separatedBy: " --> ")
        if times.count == 2 {
          currentStartTime = parseTime(times[0])
          currentEndTime = parseTime(times[1])
          print(
            "🕒 Found time cue: \(times[0]) --> \(times[1]) (\(currentStartTime ?? 0)-\(currentEndTime ?? 0))"
          )
        }
      }
      // Parse sprite coordinates (e.g., "sprite.jpg#xywh=160,0,160,90")
      else if line.contains("#xywh=") {
        let components = line.components(separatedBy: "#xywh=")
        if components.count == 2,
          let spriteImage = components.first,
          let coordString = components.last,
          let start = currentStartTime,
          let end = currentEndTime {
          let coords = coordString.split(separator: ",").compactMap { Int($0) }
          if coords.count == 4 {
            print("🎯 Found sprite coordinates: \(coords[0]),\(coords[1]),\(coords[2]),\(coords[3])")
            entries.append(
              VTTEntry(
                startTime: start,
                endTime: end,
                x: coords[0],
                y: coords[1],
                width: coords[2],
                height: coords[3],
                spriteImage: spriteImage.trimmingCharacters(in: .whitespacesAndNewlines)
              ))
          } else {
            print("⚠️ Invalid coordinate format at line \(index + 1): \(coordString)")
          }
        } else {
          print("⚠️ Malformed sprite entry at line \(index + 1): \(line)")
        }
      }
      // Try alternative format for Stash - sometimes the sprite is on the next line
      else if currentStartTime != nil && currentEndTime != nil && !line.isEmpty {
        if let nextLine = (index + 1 < lines.count) ? lines[index + 1] : nil,
          nextLine.contains("#xywh=") {
          // The sprite info is on the next line, we'll process it there
          continue
        }

        // Check if this is just the sprite filename
        if line.contains(".jpg") || line.contains(".png") {
          print("📷 Found sprite filename: \(line)")

          // Check if there's coordinate info in the next lines
          if index + 1 < lines.count {
            let nextLine = lines[index + 1]
            if nextLine.contains("#xywh=") || nextLine.contains("xywh=") {
              print("⏭️ Coordinates on next line, will process there")
              continue
            }
          }
        }
      }
    }

    print("✅ Parsed \(entries.count) thumbnail entries from VTT content")
    return entries
  }

  // Parse a WebVTT file to extract thumbnail coordinates
  public static func parseVTT(from url: URL) async -> [VTTEntry]? {
    do {
      print("🔍 Attempting to parse VTT from URL: \(url.absoluteString)")

      // Create authenticated request
      let request = createAuthenticatedRequest(url: url)
      let (data, response) = try await URLSession.shared.data(for: request)

      // Log HTTP response for debugging
      if let httpResponse = response as? HTTPURLResponse {
        print("🌐 VTT HTTP response: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
          print("❌ Error: VTT file not found (HTTP \(httpResponse.statusCode))")
          return nil
        }
      }

      guard let content = String(data: data, encoding: .utf8) else {
        print("❌ Error: Could not decode VTT content as UTF-8")
        return nil
      }

      return parseVTTContent(content)
    } catch {
      print("❌ Error parsing VTT file: \(error)")
      return nil
    }
  }

  private static func parseTime(_ time: String) -> Double {
    let parts = time.split(separator: ":")
    guard parts.count >= 2 else { return 0 }

    let hours: Double
    let minutes: Double
    let seconds: Double

    if parts.count == 3 {
      hours = Double(parts[0]) ?? 0
      minutes = Double(parts[1]) ?? 0
      seconds = Double(parts[2]) ?? 0
    } else {
      hours = 0
      minutes = Double(parts[0]) ?? 0
      seconds = Double(parts[1]) ?? 0
    }

    return hours * 3600 + minutes * 60 + seconds
  }

  // Helper to extract fingerprints from video files
  public static func findFingerprints(in files: [StashScene.SceneFile]) -> [StashScene.SceneFile
    .Fingerprint]? {
    for file in files {
      if let fingerprints = file.fingerprints, !fingerprints.isEmpty {
        return fingerprints
      }
    }
    return nil
  }

  static func createPlayerViewController(
    url: URL,
    startTime: Double? = nil,
    scenes: [StashScene] = [],
    currentIndex: Int = 0
  ) -> AVPlayerViewController {
    // Extract scene ID from URL path
    let sceneID =
      url.pathComponents
      .first { component in
        if component.hasPrefix("scene/") {
          return true
        }
        // Also check for just the number
        if Int(component) != nil {
          return true
        }
        return false
      }?
      .replacingOccurrences(of: "scene/", with: "") ?? ""

    print("🎬 Creating player for URL: \(url)")
    print("🎬 Path components: \(url.pathComponents)")
    print("🎬 Extracted scene ID: \(sceneID)")

    // Create player controller
    let playerController = AVPlayerViewController()
    let avPlayer = AVPlayer()
    playerController.player = avPlayer
    playerController.modalPresentationStyle = .fullScreen
    playerController.showsPlaybackControls = true

    // Enable volume for full screen playback
    avPlayer.isMuted = false

    // Try direct playback first
    Task {
      // Create asset with API key in headers
      let headers = [
        "ApiKey": apiKey,
        "Accept": "*/*",
        "Accept-Encoding": "identity",
        "User-Agent": "Mozilla/5.0"
      ]

      // Find the current scene in the provided scenes array
      let currentScene = scenes.first { $0.id == sceneID }

      // Debug log to see the scene paths values
      if let scene = currentScene {
        print("🔍 Scene ID: \(scene.id)")
        print("🔍 Scene paths VTT: \(scene.paths.vtt ?? "nil")")
        print("🔍 Scene paths sprite: \(scene.paths.sprite ?? "nil")")
        if let files = scene.files, !files.isEmpty, let file = files.first {
          if let fingerprints = file.fingerprints {
            for fingerprint in fingerprints {
              print("🔍 Fingerprint type: \(fingerprint.type), value: \(fingerprint.value)")
            }
          } else {
            print("🔍 No fingerprints in file")
          }
        }
      }

      // Configure asset options with thumbnail support
      var assetOptions: [String: Any] = [
        "AVURLAssetHTTPHeaderFieldsKey": headers,
        "AVURLAssetAllowsExpensiveNetworkAccess": true,
        "AVURLAssetAllowsConstrainedNetworkAccess": true,
        "_AVURLAssetOutOfBandMIMETypeKey": "application/x-mpegURL",
        "_AVURLAssetUsesNSURLSessionKey": true,
        "_AVURLAssetShouldValidateSSLCertificateKey": false
      ]

      // Add VTT thumbnail information using the scene paths if available
      if let scene = currentScene {
        // First try to use the VTT URL directly from the scene paths if available
        var vttUrl: URL?
        var spriteUrl: URL?

        // Try to use the VTT path from the API response directly - this should take precedence
        if let vttPath = scene.paths.vtt, !vttPath.isEmpty,
          let url = URL(string: vttPath) {
          // Add API key as query parameter if not already present
          if !vttPath.contains("apikey=") {
            vttUrl = addApiKeyToUrl(url)
          } else {
            vttUrl = url
          }
          print("🎬 Using VTT directly from API response: \(vttUrl?.absoluteString ?? "nil")")
        }
        // Look for the oshash in files (second priority)
        else if let files = scene.files, !files.isEmpty,
          let file = files.first(where: { $0.fingerprints != nil && !$0.fingerprints!.isEmpty }),
          let oshash = file.oshash {
          let directVttUrl = "\(serverAddress)/scene/\(oshash)_thumbs.vtt"
          if let url = URL(string: directVttUrl) {
            vttUrl = addApiKeyToUrl(url)
            print("🎬 Using VTT with oshash fingerprint: \(vttUrl?.absoluteString ?? "nil")")
          }
        }
        // Attempt to get the oshash directly via API
        else {
          // Make a direct API call to get the oshash for this scene
          if let sceneUrl = createURL(path: "/graphql", includeApiKey: true),
            let request = try? JSONSerialization.data(withJSONObject: [
              "query":
                "query FindScene($id: ID!) { findScene(id: $id) { files { fingerprints { type value } } } }",
              "variables": ["id": scene.id]
            ]) {
            var urlRequest = URLRequest(url: sceneUrl)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = request

            do {
              let (data, _) = try await URLSession.shared.data(for: urlRequest)
              if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let dataField = json["data"] as? [String: Any],
                let sceneData = dataField["findScene"] as? [String: Any],
                let files = sceneData["files"] as? [[String: Any]],
                let firstFile = files.first,
                let fingerprints = firstFile["fingerprints"] as? [[String: Any]] {
                // Look for oshash fingerprint
                for fingerprint in fingerprints {
                  if let type = fingerprint["type"] as? String, type == "oshash",
                    let oshash = fingerprint["value"] as? String {
                    print("✅ Found oshash fingerprint via player API: \(oshash)")
                    let directVttUrl = "\(serverAddress)/scene/\(oshash)_thumbs.vtt"
                    if let url = URL(string: directVttUrl) {
                      vttUrl = addApiKeyToUrl(url)
                      print("🎬 Using VTT with fetched oshash: \(vttUrl?.absoluteString ?? "nil")")
                    }
                  }
                }
              }
            } catch {
              print("❌ Error fetching oshash: \(error)")
            }
          }

          // If we still don't have a VTT URL, use the fallback method
          if vttUrl == nil {
            vttUrl = getVTTURL(forSceneID: scene.id)
            print("🎬 Using fallback VTT: \(vttUrl?.absoluteString ?? "nil")")
          }
        }

        // Try to use the sprite path from the API response directly - this should take precedence
        if let spritePath = scene.paths.sprite, !spritePath.isEmpty,
          let url = URL(string: spritePath) {
          // Add API key as query parameter if not already present
          if !spritePath.contains("apikey=") {
            spriteUrl = addApiKeyToUrl(url)
          } else {
            spriteUrl = url
          }
          print("🎬 Using sprite directly from API response: \(spriteUrl?.absoluteString ?? "nil")")
        }
        // Look for the oshash in files (second priority)
        else if let files = scene.files, !files.isEmpty,
          let file = files.first(where: { $0.fingerprints != nil && !$0.fingerprints!.isEmpty }),
          let oshash = file.oshash {
          let directSpriteUrl = "\(serverAddress)/scene/\(oshash)_sprite.jpg"
          if let url = URL(string: directSpriteUrl) {
            spriteUrl = addApiKeyToUrl(url)
            print("🎬 Using sprite with oshash fingerprint: \(spriteUrl?.absoluteString ?? "nil")")
          }
        }
        // Attempt to get the oshash directly via API (reuse the data from VTT fetch if we have it)
        else {
          // If we already fetched an oshash for the VTT, reuse it
          if let vttUrl = vttUrl, vttUrl.absoluteString.contains("_thumbs.vtt") {
            // Extract the oshash from the VTT URL
            let urlString = vttUrl.absoluteString
            if let range = urlString.range(of: "/scene/"),
              let endRange = urlString.range(of: "_thumbs.vtt") {
              let startIndex = range.upperBound
              let endIndex = endRange.lowerBound
              let oshash = String(urlString[startIndex..<endIndex])

              if !oshash.isEmpty {
                let directSpriteUrl = "\(serverAddress)/scene/\(oshash)_sprite.jpg"
                if let url = URL(string: directSpriteUrl) {
                  spriteUrl = addApiKeyToUrl(url)
                  print(
                    "🎬 Using sprite with oshash from VTT URL: \(spriteUrl?.absoluteString ?? "nil")"
                  )
                }
              }
            }
          } else {
            // Otherwise make a direct API call
            if spriteUrl == nil {
              spriteUrl = getSpriteURL(forSceneID: scene.id)
              print("🎬 Using fallback sprite URL: \(spriteUrl?.absoluteString ?? "nil")")
            }
          }
        }

        // Set up VTT data for thumbnails
        if let vttUrl = vttUrl {
          print("🎬 Using VTT thumbnail data for scrubbing from: \(vttUrl)")

          // The key without underscore is the public API
          assetOptions["AVURLAssetOutOfBandMIMETypeKey"] = "text/vtt"
          assetOptions["AVURLAssetOutOfBandSubtitleTracks"] = [
            [
              "URL": vttUrl,
              "Name": "thumbnails",
              "MIMEType": "text/vtt"
            ] as [String: Any]
          ]
        }

        // Also add sprite support
        if let spriteUrl = spriteUrl {
          print("🎬 Using sprite sheet for scrubbing from: \(spriteUrl)")

          // Enhanced sprite sheet support
          // Some players need additional metadata to connect VTT and sprite
          var enhancedHeaders = headers
          enhancedHeaders["X-Sprite-URL"] = spriteUrl.absoluteString
          assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = enhancedHeaders

          // Add metadata about sprite image for advanced players
          if assetOptions["AVMetadataCommonKeyArtwork"] == nil {
            assetOptions["AVMetadataCommonKeyArtwork"] = [
              "spriteURL": spriteUrl.absoluteString,
              "type": "thumbnails"
            ]
          }
        }
      }

      let asset = AVURLAsset(url: url, options: assetOptions)

      if #available(iOS 16.0, *) {
        do {
          let playable = try await asset.load(.isPlayable)
          await MainActor.run {
            if playable {
              let playerItem = AVPlayerItem(asset: asset)
              avPlayer.replaceCurrentItem(with: playerItem)

              // Restore previous position or use provided startTime
              let savedTime = UserDefaults.standard.getVideoProgress(for: sceneID)
              print(
                "🎬 Resume - Scene: \(sceneID), Saved time: \(savedTime), Provided startTime: \(String(describing: startTime))"
              )

              let timeToSeek = startTime ?? savedTime
              if timeToSeek > 0 {
                avPlayer.seek(to: CMTime(seconds: timeToSeek, preferredTimescale: 1))
              }

              avPlayer.play()
            }
          }
        } catch {
          print("❌ Error loading asset: \(error)")
        }
      }
    }

    return playerController
  }
}

extension UserDefaults {
  func getVideoProgress(for sceneID: String) -> Double {
    return double(forKey: "video_progress_\(sceneID)")
  }

  func setVideoProgress(_ progress: Double, for sceneID: String) {
    set(progress, forKey: "video_progress_\(sceneID)")
  }
}
