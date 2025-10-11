import Foundation
import RealityKit
import SwiftUI

@MainActor
class AppModel: ObservableObject {
  static let shared = AppModel()

  // API instance
  let api = StashAPI()

  // Connection state
  @Published var isConnected = false
  @Published var serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
  @Published var apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""

  // Content state
  @Published var selectedScene: StashScene?
  @Published var selectedPerformer: StashScene.Performer?
  @Published var selectedMarker: SceneMarker?
  @Published var selectedTag: StashScene.Tag?

  // Video state
  @Published var currentScene: StashScene?
  @Published var currentScenes: [StashScene] = []
  @Published var currentSceneIndex: Int = 0
  @Published var selectedSceneStartTime: Double?
  @Published var videoStartTime: Double = 0

  // Watch history (like iPadOS - shows recently watched scenes in dedicated view)
  @Published var watchHistory: [StashScene] = []  // Track the sequence of scenes watched

  // Navigation state
  @Published var navigationPath = NavigationPath()

  // UI state
  @Published var isShowingImmersiveSpace = false
  @Published var isShowingPlayer = false
  @Published var isShowingPerformerWindow = false
  @Published var isShowingTagEditor = false
  @Published var isShowingMarkerWindow = false
  @Published var isShowingPerformerMarkers = false
  @Published var isShowingTaggedScenes = false

  // Search state
  @Published var searchQuery: String = ""
  @Published var isSearching: Bool = false

  // Marker shuffle state
  @Published var markerShuffleQueue: [SceneMarker] = []  // Small history for previous button
  @Published var shuffleTagIds: Set<String> = []  // Tags for filtering
  @Published var shuffleSearchQuery: String = ""  // Search query for filtering
  @Published var shufflePerformerId: String? = nil  // Performer ID for filtering
  @Published var isMarkerShuffleMode: Bool = false
  @Published var currentShuffleIndex: Int = 0
  @Published var shuffleTagName: String = ""
  @Published var shuffleFilterType: String = ""

  // Tag configuration for shuffle mode - maintains equal distribution
  @Published var shuffleTagWeights: [String: Int] = [:] {
    didSet {
      // Save to UserDefaults whenever config changes
      if let data = try? JSONEncoder().encode(shuffleTagWeights) {
        UserDefaults.standard.set(data, forKey: "shuffleTagWeights")
      }
    }
  }

  // Immersive space state
  enum ImmersiveSpaceState {
    case open
    case closed
    case inTransition
  }
  @Published var immersiveSpaceState: ImmersiveSpaceState = .closed

  public init() {
    // Load saved tag weights from UserDefaults
    if let weightData = UserDefaults.standard.data(forKey: "shuffleTagWeights"),
      let weights = try? JSONDecoder().decode([String: Int].self, from: weightData)
    {
      self.shuffleTagWeights = weights
      print("📊 Loaded saved tag weights: \(weights)")
    }

    // Check if we have previously saved connection information
    let savedServerAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
    let savedApiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""

    print(
      "📱 AppModel initialized with saved server address: \(savedServerAddress.isEmpty ? "none" : savedServerAddress)"
    )
    print("📱 API key status: \(savedApiKey.isEmpty ? "not found" : "found")")

    if !savedServerAddress.isEmpty && !savedApiKey.isEmpty {
      // Auto-test connection on startup if we have saved credentials
      print("📱 Testing connection on startup with saved credentials")

      Task {
        do {
          let api = StashAPI()
          // Use a simple GraphQL query to test the connection
          let stats = try await api.fetchStats()

          await MainActor.run {
            isConnected = true
            print("✅ Auto-connection successful! Found \(stats.scene_count) scenes.")
          }
        } catch {
          print("❌ Auto-connection failed: \(error.localizedDescription)")
          // Don't update UI state as this is just an auto-test
        }
      }
    }
  }

  func setCurrentScene(_ scene: StashScene, in scenes: [StashScene]) {
    currentScene = scene
    currentScenes = scenes
    currentSceneIndex = scenes.firstIndex(of: scene) ?? 0
  }

  func updateServerAddress(_ newValue: String) {
    serverAddress = newValue
    UserDefaults.standard.set(newValue, forKey: "serverAddress")
  }

  func updateAPIKey(_ newValue: String) {
    apiKey = newValue
    UserDefaults.standard.set(newValue, forKey: "apiKey")
  }

  @MainActor
  func openScene(_ scene: StashScene, startTime: Double? = nil) {
    print(
      "🎬 AppModel.openScene called for scene \(scene.id) with startTime: \(startTime?.description ?? "nil")"
    )
    print(
      "🎬 Scene details - title: \(scene.title ?? "unknown"), stream path exists: \(scene.paths.stream != nil)"
    )

    // Use more aggressive audio cleanup to ensure no duplication
    GlobalVideoManager.shared.forceStopAllAudio()
    print("🎬 Audio cleanup completed")

    // Clear current scene first to ensure existing players are fully released
    // This is the key fix that ensures proper audio cleanup between scenes
    if currentScene != nil {
      print("🎬 Clearing existing currentScene before setting new one")
      currentScene = nil

      // Double check that any existing player is released
      GlobalVideoManager.shared.stopAllPreviews()
    }

    // Update current scene after cleanup
    currentScene = scene
    print("🎬 Set currentScene to: \(scene.id)")

    // Add to watch history (don't add duplicate if last scene is the same)
    if watchHistory.last?.id != scene.id {
      watchHistory.append(scene)
      // Keep history to reasonable size (last 20 scenes)
      if watchHistory.count > 20 {
        watchHistory = Array(watchHistory.suffix(20))
      }
      print(
        "🎯 HISTORY - Added to watch history: \(scene.title ?? scene.id) (history count: \(watchHistory.count))"
      )
    }

    // Keep currentSceneIndex in sync - find this scene in currentScenes array
    if !currentScenes.isEmpty {
      if let index = currentScenes.firstIndex(where: { $0.id == scene.id }) {
        currentSceneIndex = index
        print("🎬 Updated currentSceneIndex to \(index)/\(currentScenes.count)")
      } else {
        print(
          "⚠️ Scene '\(scene.id)' not found in currentScenes array (\(currentScenes.count) scenes)")
      }
    } else {
      print("⚠️ currentScenes is empty - buttons won't show until setCurrentScene is called")
    }

    // Set start time if provided
    if let time = startTime {
      print("🎬 AppModel.openScene setting start time to \(time) for scene \(scene.id)")
      selectedSceneStartTime = time
      videoStartTime = time

      // Save to UserDefaults
      UserDefaults.standard.set(time, forKey: "last_video_start_time")
      UserDefaults.standard.set(scene.id, forKey: "last_scene_id")
      UserDefaults.standard.synchronize()
      print("🎬 Start time \(time) saved to UserDefaults")
    } else {
      // If no explicit start time provided, check if we have one from a previous call
      let savedStartTime = UserDefaults.standard.double(forKey: "last_video_start_time")
      let savedSceneId = UserDefaults.standard.string(forKey: "last_scene_id")

      if let savedId = savedSceneId, savedId == scene.id, savedStartTime > 0 {
        print("🎬 AppModel.openScene using saved start time \(savedStartTime) for scene \(scene.id)")
        selectedSceneStartTime = savedStartTime
        videoStartTime = savedStartTime
      } else {
        // Clear any existing start time if we're not using a saved one
        print("🎬 AppModel.openScene resetting start time for scene \(scene.id)")
        selectedSceneStartTime = nil
        videoStartTime = 0
      }
    }

    // Selected scene should match current scene for consistency
    selectedScene = scene
    print("🎬 Set selectedScene to: \(scene.id)")

    // Show the player - short delay to ensure we have a clean state
    Task { @MainActor in
      print("🎬 Starting task to show player...")
      // Very short delay to ensure state is updated
      try? await Task.sleep(for: .milliseconds(100))
      print("🎬 Setting isShowingPlayer = true")
      isShowingPlayer = true
      print("🎬 AppModel.openScene completed - player should now be visible for scene: \(scene.id)")
    }
  }

  func openPerformer(_ performer: StashScene.Performer) {
    selectedPerformer = performer
    isShowingPerformerWindow = true
  }

  func openMarker(_ marker: SceneMarker) {
    selectedMarker = marker
    isShowingMarkerWindow = true
  }

  func openTag(_ tag: StashScene.Tag) {
    selectedTag = tag
    isShowingTaggedScenes = true
  }

  func cleanupResources() {
    // Reset immersive space state
    immersiveSpaceState = .closed

    // Close any open windows
    isShowingPlayer = false
    isShowingImmersiveSpace = false
    isShowingPerformerWindow = false
    isShowingMarkerWindow = false

    // Cleanup any preview players that might be active
    GlobalVideoManager.shared.stopAllPreviews()

    print("🧹 App resources cleaned up due to app state change")
  }

  // MARK: - Marker Shuffle Methods

  /// Set configuration for a tag (currently tags get equal distribution)
  /// All tags receive equal representation in shuffle regardless of marker count
  func setTagWeight(tagId: String, weight: Int) {
    shuffleTagWeights[tagId] = weight
    print(
      "⚖️ Set config for tag \(tagId): \(weight) (equal distribution - all tags get same chance)")
  }

  /// Start marker shuffle for a specific tag
  func startMarkerShuffle(forTag tagId: String, tagName: String, displayedMarkers: [SceneMarker]) {
    print("🎲 Starting API-based marker shuffle for tag: \(tagName)")

    Task { @MainActor in
      self.isMarkerShuffleMode = true
      self.shuffleTagName = tagName
      self.shuffleFilterType = "tag"
      self.currentShuffleIndex = 0
      self.shuffleTagIds = [tagId]
      self.shuffleSearchQuery = ""
      self.markerShuffleQueue = []  // Clear history
    }

    // Store shuffle mode in UserDefaults for player continuity
    UserDefaults.standard.set(true, forKey: "isMarkerShuffleMode")
    UserDefaults.standard.set(tagName, forKey: "shuffleTagName")
    UserDefaults.standard.set("tag", forKey: "shuffleFilterType")

    // Fetch first random marker from API
    Task {
      if let randomMarker = await api.fetchRandomMarker(tagIds: [tagId]) {
        await MainActor.run {
          self.markerShuffleQueue = [randomMarker]  // Start history with first marker
          self.navigateToMarker(randomMarker)
        }
      } else {
        print("⚠️ No markers found for shuffle")
      }
    }
  }

  /// Start marker shuffle for multiple tags
  func startMarkerShuffle(
    forMultipleTags tagIds: [String], tagNames: [String], displayedMarkers: [SceneMarker]
  ) {
    let combinedTagName = tagNames.joined(separator: " + ")
    print("🎲 Starting API-based multi-tag shuffle for: \(combinedTagName)")

    Task { @MainActor in
      self.isMarkerShuffleMode = true
      self.shuffleTagName = combinedTagName
      self.shuffleFilterType = "multi-tag"
      self.currentShuffleIndex = 0
      self.shuffleTagIds = Set(tagIds)
      self.shuffleSearchQuery = ""
      self.markerShuffleQueue = []  // Clear history
    }

    // Store shuffle mode in UserDefaults
    UserDefaults.standard.set(true, forKey: "isMarkerShuffleMode")
    UserDefaults.standard.set(combinedTagName, forKey: "shuffleTagName")
    UserDefaults.standard.set("multi-tag", forKey: "shuffleFilterType")

    // Fetch first random marker from API
    Task {
      if let randomMarker = await api.fetchRandomMarker(tagIds: Set(tagIds)) {
        await MainActor.run {
          self.markerShuffleQueue = [randomMarker]  // Start history with first marker
          self.navigateToMarker(randomMarker)
        }
      } else {
        print("⚠️ No markers found for shuffle")
      }
    }
  }

  /// Start marker shuffle for search query
  func startMarkerShuffle(forSearchQuery query: String, displayedMarkers: [SceneMarker]) {
    print("🎲 Starting API-based marker shuffle for search: '\(query)'")

    Task { @MainActor in
      self.isMarkerShuffleMode = true
      self.shuffleTagName = query.isEmpty ? "All Markers" : "Search: \(query)"
      self.shuffleFilterType = "search"
      self.currentShuffleIndex = 0
      self.shuffleTagIds = []
      self.shuffleSearchQuery = query
      self.markerShuffleQueue = []  // Clear history
    }

    // Store shuffle mode in UserDefaults
    UserDefaults.standard.set(true, forKey: "isMarkerShuffleMode")
    UserDefaults.standard.set(self.shuffleTagName, forKey: "shuffleTagName")
    UserDefaults.standard.set("search", forKey: "shuffleFilterType")

    // Fetch first random marker from API
    Task {
      if let randomMarker = await api.fetchRandomMarker(searchQuery: query.isEmpty ? nil : query) {
        await MainActor.run {
          self.markerShuffleQueue = [randomMarker]  // Start history with first marker
          self.navigateToMarker(randomMarker)
        }
      } else {
        print("⚠️ No markers found for shuffle")
      }
    }
  }

  /// Start marker shuffle for a specific performer
  func startMarkerShuffle(
    forPerformer performer: StashScene.Performer, displayedMarkers: [SceneMarker]
  ) {
    print("🎲 Starting API-based marker shuffle for performer: \(performer.name)")

    Task { @MainActor in
      self.isMarkerShuffleMode = true
      self.shuffleTagName = "Performer: \(performer.name)"
      self.shuffleFilterType = "performer"
      self.currentShuffleIndex = 0
      self.shuffleTagIds = []
      self.shuffleSearchQuery = ""  // Clear search query
      self.shufflePerformerId = performer.id  // Store performer ID for filtering
      self.markerShuffleQueue = []  // Clear history
    }

    // Store shuffle mode in UserDefaults
    UserDefaults.standard.set(true, forKey: "isMarkerShuffleMode")
    UserDefaults.standard.set(self.shuffleTagName, forKey: "shuffleTagName")
    UserDefaults.standard.set("performer", forKey: "shuffleFilterType")

    // Fetch first random marker from API using performer ID filter
    Task {
      if let randomMarker = await api.fetchRandomMarker(performerId: performer.id) {
        await MainActor.run {
          self.markerShuffleQueue = [randomMarker]  // Start history with first marker
          self.navigateToMarker(randomMarker)
        }
      } else {
        print("⚠️ No markers found for performer shuffle")
      }
    }
  }

  /// Navigate to a specific marker
  func navigateToMarker(_ marker: SceneMarker) {
    print(
      "🎬 navigateToMarker called for: \(marker.title) at \(marker.seconds) seconds (marker ID: \(marker.id))"
    )

    // Clear any existing video state
    GlobalVideoManager.shared.forceStopAllAudio()
    print("🎬 Audio cleared, checking marker scene data...")

    // We need to fetch the full scene data because marker scene data is limited
    guard let scene = marker.scene else {
      print("⚠️ No scene data available for marker - this is a critical error!")
      return
    }
    print("🎬 Marker has scene data: ID=\(scene.id), title=\(scene.title ?? "unknown")")

    // Fetch full scene data from API
    Task {
      print("🎬 Starting async task to fetch full scene data for scene ID: \(scene.id)")
      do {
        print("🎬 Calling api.fetchScene(byID: \(scene.id))...")
        if let fullScene = try await api.fetchScene(byID: scene.id) {
          print("🎬 Successfully fetched full scene data for: \(fullScene.title ?? fullScene.id)")
          await MainActor.run {
            print("🎬 On MainActor - calling openScene with startTime: \(marker.seconds)")
            self.openScene(fullScene, startTime: marker.seconds)
            self.isShowingPlayer = true

            print(
              "🎬 Scene opened and player showing flag set - marker should be playing at \(marker.seconds) seconds"
            )
          }
        } else {
          print("⚠️ fetchScene returned nil for scene ID: \(scene.id) - using fallback")
          await self.navigateToMarkerFallback(marker)
        }
      } catch {
        print("❌ Error fetching full scene data for scene ID \(scene.id): \(error)")
        if let apiError = error as? URLError {
          print("❌ URLError details: \(apiError.localizedDescription)")
        }
        // Fallback to creating scene from limited marker data
        print("🎬 Using fallback navigation...")
        await self.navigateToMarkerFallback(marker)
      }
    }
  }

  /// Fallback navigation using limited marker data
  private func navigateToMarkerFallback(_ marker: SceneMarker) async {
    guard let scene = marker.scene else { return }

    // Convert performer info to performers
    let performers: [StashScene.Performer]? = scene.performers?.map { performerInfo in
      StashScene.Performer(
        id: performerInfo.id,
        name: performerInfo.name,
        gender: nil,
        url: nil,
        twitter: nil,
        instagram: nil,
        image_path: performerInfo.image_path,
        scene_count: 0,
        image_count: 0,
        gallery_count: nil,
        rating100: nil,
        favorite: nil,
        country: nil,
        height_cm: nil,
        fake_tits: nil,
        career_length: nil,
        tattoos: nil,
        piercings: nil,
        aliases: nil,
        tags: nil,
        stash_ids: nil,
        created_at: nil,
        updated_at: nil,
        details: nil
      )
    }

    // Create a basic StashScene from the marker's scene data
    let stashScene = StashScene(
      id: scene.id,
      title: scene.title,
      details: nil,
      url: nil,
      date: nil,
      rating100: nil,
      organized: nil,
      oCounter: nil,
      paths: StashScene.ScenePaths(
        screenshot: "",
        preview: nil,
        stream: marker.stream,
        webp: nil,
        vtt: nil,
        sprite: nil,
        funscript: nil,
        interactive_heatmap: nil
      ),
      files: scene.files?.map { fileInfo in
        StashScene.SceneFile(
          size: nil,
          duration: nil,
          video_codec: nil,
          audio_codec: nil,
          width: fileInfo.width,
          height: fileInfo.height,
          framerate: nil,
          bitrate: nil,
          fingerprints: nil
        )
      } ?? [],
      performers: performers,
      tags: nil,
      studio: nil,
      stashIds: nil,
      createdAt: nil,
      updatedAt: nil
    )

    await MainActor.run {
      // Open the scene at the marker's timestamp
      self.openScene(stashScene, startTime: marker.seconds)
    }
  }

  /// Navigate to a specific scene
  func navigateToScene(_ scene: StashScene) {
    print("🎬 Navigating to scene: \(scene.title ?? scene.id)")
    selectedScene = scene
    currentScene = scene
    openScene(scene)
  }

  /// Navigate to next scene in current context with random timestamp
  func nextScene() {
    guard !currentScenes.isEmpty else {
      print("⚠️ No scenes available for navigation")
      return
    }

    // Move to next scene (wrap around to beginning)
    let oldIndex = currentSceneIndex
    currentSceneIndex = (currentSceneIndex + 1) % currentScenes.count
    let nextScene = currentScenes[currentSceneIndex]

    // Calculate random timestamp
    let videoDuration = nextScene.files?.first?.duration ?? 0
    var randomStartTime: Double = 0

    if videoDuration > 0 {
      // Random position between 30% and 75% of duration
      let minOffset = videoDuration * 0.3
      let maxOffset = videoDuration * 0.75
      randomStartTime = Double.random(in: minOffset...maxOffset)
    }

    print(
      "⏭️ Next: [\(oldIndex) → \(currentSceneIndex)/\(currentScenes.count)] '\(nextScene.title ?? nextScene.id)' @ \(Int(randomStartTime))s"
    )
    print("⏭️ Next scene ID: \(nextScene.id)")
    print("⏭️ Video duration was: \(videoDuration) seconds")
    print("⏭️ Calculated random start time: \(randomStartTime) seconds")

    // Use notification-based switching for reliable start time
    GlobalVideoManager.shared.stopAllPreviews()
    print("⏭️ Stopped all previews")

    // Reset state
    UserDefaults.standard.removeObject(forKey: "last_video_start_time")
    UserDefaults.standard.removeObject(forKey: "last_scene_id")
    UserDefaults.standard.synchronize()

    videoStartTime = 0
    selectedSceneStartTime = nil

    // Send pause notification
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      print("⏭️ Sending pause notification")
      NotificationCenter.default.post(
        name: .videoPlayerShouldSwitch,
        object: nil,
        userInfo: ["pauseOnly": true]
      )

      // Send switch notification with start time
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        print("⏭️ Sending switch notification with startTime: \(randomStartTime)")
        NotificationCenter.default.post(
          name: .videoPlayerShouldSwitch,
          object: nil,
          userInfo: [
            "sceneID": nextScene.id,
            "startTime": randomStartTime,
            "forcePlay": true,
          ]
        )

        // Also call openScene as backup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          print("⏭️ Setting UserDefaults and calling openScene with startTime: \(randomStartTime)")
          UserDefaults.standard.set(randomStartTime, forKey: "last_video_start_time")
          UserDefaults.standard.set(nextScene.id, forKey: "last_scene_id")
          UserDefaults.standard.synchronize()

          self.videoStartTime = randomStartTime
          self.selectedSceneStartTime = randomStartTime
          print("⏭️ About to call openScene with startTime: \(randomStartTime)")
          self.openScene(nextScene, startTime: randomStartTime)
        }
      }
    }
  }

  /// Navigate to previous scene in current context with random timestamp
  func previousScene() {
    guard !currentScenes.isEmpty else {
      print("⚠️ No scenes available for navigation")
      return
    }

    // Move to previous scene (wrap around to end)
    let oldIndex = currentSceneIndex
    currentSceneIndex = currentSceneIndex > 0 ? currentSceneIndex - 1 : currentScenes.count - 1
    let prevScene = currentScenes[currentSceneIndex]

    // Calculate random timestamp
    let videoDuration = prevScene.files?.first?.duration ?? 0
    var randomStartTime: Double = 0

    if videoDuration > 0 {
      // Random position between 30% and 75% of duration
      let minOffset = videoDuration * 0.3
      let maxOffset = videoDuration * 0.75
      randomStartTime = Double.random(in: minOffset...maxOffset)
    }

    print(
      "⏮️ Previous: [\(oldIndex) → \(currentSceneIndex)/\(currentScenes.count)] '\(prevScene.title ?? prevScene.id)' @ \(Int(randomStartTime))s"
    )

    // Use notification-based switching for reliable start time
    GlobalVideoManager.shared.stopAllPreviews()

    // Reset state
    UserDefaults.standard.removeObject(forKey: "last_video_start_time")
    UserDefaults.standard.removeObject(forKey: "last_scene_id")
    UserDefaults.standard.synchronize()

    videoStartTime = 0
    selectedSceneStartTime = nil

    // Send pause notification
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      NotificationCenter.default.post(
        name: .videoPlayerShouldSwitch,
        object: nil,
        userInfo: ["pauseOnly": true]
      )

      // Send switch notification with start time
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(
          name: .videoPlayerShouldSwitch,
          object: nil,
          userInfo: [
            "sceneID": prevScene.id,
            "startTime": randomStartTime,
            "forcePlay": true,
          ]
        )

        // Also call openScene as backup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          UserDefaults.standard.set(randomStartTime, forKey: "last_video_start_time")
          UserDefaults.standard.set(prevScene.id, forKey: "last_scene_id")
          UserDefaults.standard.synchronize()

          self.videoStartTime = randomStartTime
          self.selectedSceneStartTime = randomStartTime
          self.openScene(prevScene, startTime: randomStartTime)
        }
      }
    }
  }

  /// Navigate to a specific performer
  func navigateToPerformer(_ performer: StashScene.Performer) {
    print("👤 Navigating to performer: \(performer.name)")
    selectedPerformer = performer
    isShowingPerformerWindow = true
  }

  /// Move to the next marker in shuffle queue - fetches from API
  func nextMarkerInShuffle() {
    guard isMarkerShuffleMode else {
      print("⚠️ Not in marker shuffle mode")
      return
    }

    print("🎲 nextMarkerInShuffle called - current shuffle mode: \(shuffleFilterType)")
    print(
      "🎲 Shuffle state - tagIds: \(shuffleTagIds), performerId: \(shufflePerformerId ?? "nil"), searchQuery: '\(shuffleSearchQuery)'"
    )

    // Fetch a new random marker from API based on current filters
    Task {
      print("🎲 Starting async task to fetch next marker...")
      let randomMarker: SceneMarker?

      if let performerId = shufflePerformerId {
        // Performer-based shuffle
        print("🎲 Fetching performer-based shuffle for: \(performerId)")
        randomMarker = await api.fetchRandomMarker(performerId: performerId)
      } else if !shuffleTagIds.isEmpty {
        // Tag-based shuffle with equal distribution
        print("🎲 Fetching tag-based shuffle for: \(shuffleTagIds)")
        print("🎲 Using equal distribution for all tags")
        randomMarker = await api.fetchRandomMarker(
          tagIds: shuffleTagIds, tagWeights: shuffleTagWeights)
      } else if !shuffleSearchQuery.isEmpty {
        // Search-based shuffle
        print("🎲 Fetching search-based shuffle for: '\(shuffleSearchQuery)'")
        randomMarker = await api.fetchRandomMarker(searchQuery: shuffleSearchQuery)
      } else {
        // General shuffle
        print("🎲 Fetching general shuffle (no filters)")
        randomMarker = await api.fetchRandomMarker()
      }

      print("🎲 API call completed, randomMarker: \(randomMarker != nil ? "found" : "nil")")

      if let marker = randomMarker {
        print("🎲 Got marker: \(marker.title) (ID: \(marker.id)) - updating UI on MainActor")
        await MainActor.run {
          // Add to history (keep last 10)
          self.markerShuffleQueue.append(marker)
          if self.markerShuffleQueue.count > 10 {
            self.markerShuffleQueue.removeFirst()
          }
          self.currentShuffleIndex = self.markerShuffleQueue.count - 1

          print(
            "🎲 Next marker: \(marker.title) (history: \(self.markerShuffleQueue.count) markers)")
          print("🎲 Calling navigateToMarker...")
          self.navigateToMarker(marker)
        }
      } else {
        print("⚠️ Failed to fetch next marker from API - randomMarker was nil")
      }
    }
  }

  /// Move to the previous marker in shuffle queue - uses history
  func previousMarkerInShuffle() {
    guard isMarkerShuffleMode && !markerShuffleQueue.isEmpty else {
      print("⚠️ Not in marker shuffle mode or history is empty")
      return
    }

    // Navigate to previous in history if available
    if currentShuffleIndex > 0 {
      currentShuffleIndex -= 1
      let previousMarker = markerShuffleQueue[currentShuffleIndex]

      print(
        "🎲 Previous marker from history: \(previousMarker.title) (index \(currentShuffleIndex) of \(markerShuffleQueue.count))"
      )
      navigateToMarker(previousMarker)
    } else {
      print("⚠️ Already at the beginning of marker history")
    }
  }

  /// Stop marker shuffle mode
  func stopMarkerShuffle() {
    print("🛑 Stopping marker shuffle mode")
    Task { @MainActor in
      self.isMarkerShuffleMode = false
      self.markerShuffleQueue = []
      self.currentShuffleIndex = 0
      self.shuffleTagName = ""
      self.shuffleFilterType = ""
      self.shuffleTagIds = []
      self.shuffleSearchQuery = ""
      self.shufflePerformerId = nil
    }

    // Clear from UserDefaults
    UserDefaults.standard.set(false, forKey: "isMarkerShuffleMode")
    UserDefaults.standard.removeObject(forKey: "shuffleTagName")
    UserDefaults.standard.removeObject(forKey: "shuffleFilterType")
  }
}
