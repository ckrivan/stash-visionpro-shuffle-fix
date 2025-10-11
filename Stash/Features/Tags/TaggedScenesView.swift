import AVKit
import Combine
import ObjectiveC
import SwiftUI

struct TaggedScenesView: View {
  let tag: StashScene.Tag
  @StateObject private var api = StashAPI()
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var totalScenes = 0
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // Loading state
      if api.isLoading && api.scenes.isEmpty {
        LoadingView(tagName: tag.name)
      }
      // Empty state
      else if api.scenes.isEmpty {
        EmptyStateView(tagName: tag.name)
      }
      // Content
      else {
        TagScenesContent(
          scenes: api.scenes,
          isLoadingMore: isLoadingMore,
          onDelete: handleSceneDeleted
        ) {
          if !isLoadingMore && hasMorePages {
            Task {
              await loadMore()
            }
          }
        }
      }
    }
    .navigationTitle("\(tag.name) (\(totalScenes))")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        // Add a random jump button for all scenes with this tag
        Button(action: {
          randomJump()
        }) {
          HStack {
            Image(systemName: "shuffle.circle.fill")
            Text("Random")
          }
          .foregroundColor(.purple)
        }
        .disabled(api.scenes.isEmpty)
      }

      ToolbarItem(placement: .cancellationAction) {
        Button("Done") { dismiss() }
      }
    }
    .task {
      await loadInitial()
    }
    .onAppear {
      // Save the current scenes in the app model for easy navigation
      appModel.currentScenes = api.scenes
    }
    .onChange(of: api.scenes) { _, newScenes in
      // Update app model when scenes change
      appModel.currentScenes = newScenes
    }
  }

  private func randomJump() {
    guard !api.scenes.isEmpty else { return }

    print("🎲 TaggedScenesView.randomJump - Starting random jump for tag: \(tag.name)")
    print("🎲 Currently loaded scenes: \(api.scenes.count) out of \(totalScenes) total")

    // If we haven't loaded all scenes yet, load them all first
    if api.scenes.count < totalScenes {
      print("🎲 Loading all \(totalScenes) scenes before shuffling...")

      Task {
        // Load all remaining pages
        while api.scenes.count < totalScenes && hasMorePages {
          await loadMore()
        }

        print("🎲 Finished loading all scenes: \(api.scenes.count) total")

        // Now do the random jump with all scenes loaded
        await performRandomJump()
      }
      return
    }

    // We already have all scenes loaded, do the jump immediately
    Task {
      await performRandomJump()
    }
  }

  private func performRandomJump() async {
    print("🎲 performRandomJump with \(api.scenes.count) scenes available")
    print("🎲 First 5 scene titles: \(api.scenes.prefix(5).map { $0.title ?? "untitled" })")

    // Pick a random scene from the current tag's scenes
    guard let randomScene = api.scenes.randomElement() else {
      print("❌ Failed to get random scene")
      return
    }

    print("🎲 Selected random scene: \(randomScene.title ?? randomScene.id) (ID: \(randomScene.id))")

    // Calculate random start time for this scene
    let videoDuration = randomScene.files?.first?.duration ?? 0
    print(
      "🎲 Video duration: \(videoDuration) seconds (from files: \(randomScene.files?.count ?? 0))")

    let randomStartTime: Double

    if videoDuration > 0 {
      // Calculate random position (30% to 70% of duration)
      let minOffset = videoDuration * 0.3
      let maxOffset = videoDuration * 0.7
      randomStartTime = Double.random(in: minOffset...maxOffset)
      print("🎲 Random range: \(minOffset) to \(maxOffset)")
    } else {
      // Default to 2 minutes in if we can't determine duration
      randomStartTime = 120
      print("⚠️ No duration found, defaulting to 120 seconds")
    }

    print("🎲 ✅ Final calculated random start time: \(randomStartTime) seconds")

    await MainActor.run {
      // Stop ANY video preview that might be playing
      GlobalVideoManager.shared.stopAllPreviews()

      // COMPLETELY RESET UserDefaults and model state
      UserDefaults.standard.removeObject(forKey: "last_video_start_time")
      UserDefaults.standard.removeObject(forKey: "last_scene_id")
      UserDefaults.standard.synchronize()

      // Clean model state
      self.appModel.videoStartTime = 0
      self.appModel.selectedSceneStartTime = nil
    }

    // Wait for complete reset
    try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

    await MainActor.run {
      print("🎲 Sending notification for scene \(randomScene.id) at time \(randomStartTime)")

      // First pause any current video
      NotificationCenter.default.post(
        name: .videoPlayerShouldSwitch,
        object: nil,
        userInfo: ["pauseOnly": true]
      )
    }

    // Wait before sending switch notification
    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    await MainActor.run {
      NotificationCenter.default.post(
        name: .videoPlayerShouldSwitch,
        object: nil,
        userInfo: [
          "sceneID": randomScene.id,
          "startTime": randomStartTime,
          "forcePlay": true,
        ]
      )
    }

    // Wait before opening scene
    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    await MainActor.run {
      // Set fresh UserDefaults values
      UserDefaults.standard.set(randomStartTime, forKey: "last_video_start_time")
      UserDefaults.standard.set(randomScene.id, forKey: "last_scene_id")
      UserDefaults.standard.synchronize()

      self.appModel.videoStartTime = randomStartTime
      self.appModel.selectedSceneStartTime = randomStartTime

      // IMPORTANT: Set the current scenes list BEFORE opening the scene
      // This ensures next/previous navigation works correctly within this tag
      print(
        "🎲 Setting currentScenes to tag '\(self.tag.name)' scenes: \(self.api.scenes.count) total")
      self.appModel.currentScenes = self.api.scenes
      self.appModel.setCurrentScene(randomScene, in: self.api.scenes)

      print(
        "🎲 currentSceneIndex: \(self.appModel.currentSceneIndex)/\(self.appModel.currentScenes.count)"
      )

      self.appModel.openScene(randomScene, startTime: randomStartTime)

      print("🎲 Random jump complete - scene should start at \(randomStartTime)")
    }
  }

  private func loadInitial() async {
    currentPage = 1
    hasMorePages = true
    api.isLoading = true

    do {
      // Create a filter with just this tag ID
      print(
        "🏷️ Loading scenes for tag: \(tag.name) (ID: \(tag.id), scene_count: \(tag.scene_count ?? 0))"
      )
      let filter = SceneFilterType(tags: [tag.id])
      print("🔍 Created filter with tag ID: \(tag.id)")

      // Debug log the authorization being used
      print("🔐 Using API key: \(api.apiKey.prefix(10))...")
      print("🔗 Server URL: \(api.serverAddress)")

      let result = try await api.findScenes(filter: filter, page: currentPage)

      print("✅ API call succeeded, got \(result.scenes.count) scenes out of \(result.count) total")

      await MainActor.run {
        api.scenes = result.scenes
        totalScenes = result.count
        hasMorePages = result.scenes.count < result.count
        api.isLoading = false

        // Additional debugging
        print("🔄 Updated UI state: hasMorePages=\(hasMorePages), isLoading=\(api.isLoading)")
        print("📱 Current scenes in UI: \(api.scenes.count)")
      }

      print("📊 Loaded \(result.scenes.count) scenes with tag \(tag.name) (total: \(result.count))")
    } catch {
      print("❌ Error loading scenes with tag: \(error)")
      if let apiError = error as? StashAPIError {
        print("🚨 StashAPIError: \(apiError.localizedDescription)")
      } else if let decodingError = error as? DecodingError {
        print("🚨 DecodingError: \(decodingError)")
      } else if let urlError = error as? URLError {
        print("🚨 URLError: \(urlError.localizedDescription) (code: \(urlError.code.rawValue))")
      }

      await MainActor.run {
        api.isLoading = false
      }
    }
  }

  private func loadMore() async {
    guard !isLoadingMore && hasMorePages else { return }

    isLoadingMore = true
    currentPage += 1

    do {
      // Create a filter with just this tag ID
      let filter = SceneFilterType(tags: [tag.id])
      let result = try await api.findScenes(filter: filter, page: currentPage)

      await MainActor.run {
        // Filter out duplicates before appending
        let newScenes = result.scenes.filter { newScene in
          !api.scenes.contains { $0.id == newScene.id }
        }
        api.scenes.append(contentsOf: newScenes)
        totalScenes = result.count
        hasMorePages = api.scenes.count < result.count
        isLoadingMore = false
      }

      print(
        "📊 Loaded additional \(result.scenes.count) scenes with tag \(tag.name) (page \(currentPage))"
      )
    } catch {
      print("❌ Error loading more scenes with tag: \(error)")
      await MainActor.run {
        isLoadingMore = false
      }
    }
  }

  // Handle scene deletion (if supported)
  private func handleSceneDeleted(_ sceneId: String) {
    // Remove the scene from our local collection
    api.scenes.removeAll { $0.id == sceneId }

    // Update total count
    totalScenes -= 1

    // Update app model's current scenes
    appModel.currentScenes = api.scenes

    // If we've deleted everything, reload to show empty state
    if api.scenes.isEmpty {
      Task {
        await loadInitial()
      }
    }
  }
}

// Loading view extracted as a separate component
struct LoadingView: View {
  let tagName: String

  var body: some View {
    ProgressView("Loading scenes with tag: \(tagName)...")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// Empty state view extracted as a separate component
struct EmptyStateView: View {
  let tagName: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "tag.slash")
        .font(.system(size: 60))
        .foregroundColor(.secondary)
      Text("No scenes found with tag: \(tagName)")
        .font(.title2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// Content view extracted as a separate component
struct TagScenesContent: View {
  let scenes: [StashScene]
  let isLoadingMore: Bool
  let onDelete: (String) -> Void
  let onLastSceneAppear: () -> Void

  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
        ForEach(scenes) { scene in
          // Use SceneRow with debugging modifier
          DirectSceneRow(scene: scene, allScenes: scenes, onDelete: onDelete)
            .onAppear {
              if scene == scenes.last {
                onLastSceneAppear()
              }
            }
        }

        if isLoadingMore {
          ProgressView()
            .gridCellColumns(1)
            .padding()
        }
      }
      .padding()
    }
  }
}

// Direct implementation of SceneRow for tag view that preserves random jump functionality
struct DirectSceneRow: View {
  let scene: StashScene
  let allScenes: [StashScene]
  let onDelete: (String) -> Void
  @State private var isShuffling = false
  @State private var isPreviewPlaying = false
  @State private var previewLoaded = false
  @State private var isFullScreen = false
  @State private var player: AVPlayer?
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel

  private var previewURL: URL? {
    guard let previewPath = scene.paths.preview else { return nil }
    return URL(string: previewPath)
  }

  var body: some View {
    VStack(alignment: .leading) {
      // Thumbnail with overlay for random jump
      ZStack {
        // Thumbnail image
        if let screenshot = scene.paths.screenshot,
          let screenshotURL = URL(string: screenshot)
        {
          AsyncImage(url: screenshotURL) { image in
            image.resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Rectangle()
              .fill(.ultraThinMaterial)
          }
          .aspectRatio(16 / 9, contentMode: .fill)
          .frame(minHeight: 180)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .opacity(isPreviewPlaying ? 0 : 1)
          .animation(.easeInOut(duration: 0.3), value: isPreviewPlaying)
        } else {
          Rectangle()
            .fill(.ultraThinMaterial)
            .aspectRatio(16 / 9, contentMode: .fill)
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        // Video preview (shown when isPreviewPlaying is true)
        if let url = previewURL, isPreviewPlaying {
          VideoPlayer(player: player)
            .aspectRatio(16 / 9, contentMode: .fill)
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
              if !previewLoaded {
                previewLoaded = true
                setupPreviewPlayer(previewURL: url)
              }
              player?.play()
            }
            .onDisappear {
              player?.pause()
            }
            .transition(.opacity)
        }

        // Random Jump button overlay - at bottom left
        VStack {
          Spacer()
          HStack {
            Button {
              completelyDirectRandomJump()
            } label: {
              HStack {
                Image(systemName: "shuffle.circle.fill")
                Text("Random Jump")
              }
              .font(.caption.bold())
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.purple.opacity(0.8))
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()
          }
          .padding(12)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        // Toggle preview playback on tap
        isPreviewPlaying.toggle()
        if isPreviewPlaying {
          GlobalVideoManager.shared.stopAllPreviews()
          if player == nil, let previewURL = self.previewURL {
            setupPreviewPlayer(previewURL: previewURL)
          }
          player?.play()
        } else {
          player?.pause()
        }
      }
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 0.5)
          .onEnded { _ in
            // Enter full screen on long press
            isFullScreen = true
          }
      )

      VStack(alignment: .leading, spacing: 8) {
        // Title - now plays video when tapped
        Button(action: {
          // Set scene context for navigation
          appModel.setCurrentScene(scene, in: allScenes)
          // Use standard opening without the full reset to keep last position
          appModel.openScene(scene)
        }) {
          Text(scene.title ?? "Untitled")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)

        // Performers
        if let performers = scene.performers,
          !performers.isEmpty
        {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(performers) { performer in
                NavigationLink(value: Route.performer(performer)) {
                  Text(performer.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
              }
            }
          }
          .scrollClipDisabled()
        }

        // Tags
        if let tags = scene.tags,
          !tags.isEmpty
        {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(tags) { tag in
                NavigationLink(value: Route.tag(tag)) {
                  Text(tag.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
              }
            }
          }
          .scrollClipDisabled()
        }
      }
      .padding(16)
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .fullScreenCover(isPresented: $isFullScreen) {
      VideoPlayerView(scene: scene)
        .environmentObject(appModel)
        .environmentObject(navigationModel)
    }
    .onDisappear {
      // Clean up preview when this view disappears
      if isPreviewPlaying {
        cleanupPlayer()
        isPreviewPlaying = false
        previewLoaded = false
      }
    }
  }

  // Setup player for preview
  private func setupPreviewPlayer(previewURL: URL) {
    // Clean up any existing player first
    cleanupPlayer()

    // Set up asset with required headers if needed
    let headers = [
      "Accept": "*/*",
      "Accept-Encoding": "identity",
      "Accept-Language": "en-US,en;q=0.9",
      "User-Agent": "Mozilla/5.0",
      "Connection": "keep-alive",
    ]

    let asset = AVURLAsset(
      url: previewURL,
      options: [
        "AVURLAssetHTTPHeaderFieldsKey": headers
      ])

    let playerItem = AVPlayerItem(asset: asset)
    playerItem.preferredForwardBufferDuration = 10
    player = AVPlayer(playerItem: playerItem)
    player?.automaticallyWaitsToMinimizeStalling = true
    player?.isMuted = true  // Preview is muted by default

    // Register player with manager for global control
    if let player = player {
      GlobalVideoManager.shared.registerPlayer(player)
      // Always start playing immediately
      player.play()
    }

    // Add loop observer to continue playing in a loop
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak player] _ in
      player?.seek(to: .zero)
      // Continue playing when it reaches the end
      player?.play()
    }

    // Also observe status to auto-play when ready
    let observation = playerItem.observe(\AVPlayerItem.status) { item, _ in
      if item.status == .readyToPlay {
        DispatchQueue.main.async {
          self.player?.play()
        }
      }
    }
    // Keep observation alive
    objc_setAssociatedObject(
      playerItem, UnsafeRawPointer(bitPattern: 1)!, observation, .OBJC_ASSOCIATION_RETAIN)
  }

  // Cleanup player resources
  private func cleanupPlayer() {
    if let player = player {
      player.pause()
      GlobalVideoManager.shared.unregisterPlayer(player)

      // Remove all observers associated with this player
      NotificationCenter.default.removeObserver(
        self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    player = nil
  }

  // Direct implementation of random jump functionality - completely bypassing complex stack
  private func completelyDirectRandomJump() {
    guard !isShuffling else { return }
    isShuffling = true

    print("🔴 EMERGENCY: Attempting direct random jump for scene \(scene.id)")

    // Stop ANY video preview that might be playing
    GlobalVideoManager.shared.stopAllPreviews()

    // Determine video duration
    let videoDuration = scene.files?.first?.duration ?? 0
    var randomStartTime: Double = 0

    if videoDuration > 0 {
      // Calculate random position (using simpler logic)
      randomStartTime = max(videoDuration * 0.3, 60)  // At least 30% in or 60 seconds
      randomStartTime = min(randomStartTime, videoDuration - 60)  // No closer than 60s to end
    } else {
      // Default to 2 minutes in if we can't determine duration
      randomStartTime = 120
    }

    print("🔴 EMERGENCY: Using random start time: \(randomStartTime)")

    // COMPLETELY RESET UserDefaults and model state
    UserDefaults.standard.removeObject(forKey: "last_video_start_time")
    UserDefaults.standard.removeObject(forKey: "last_scene_id")
    UserDefaults.standard.synchronize()

    // Clean model state
    appModel.videoStartTime = 0
    appModel.selectedSceneStartTime = nil

    // Wait for complete reset
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      // Now use a direct approach with a hardcoded parameter in a notification
      print(
        "🔴 EMERGENCY: Sending direct notification for scene \(self.scene.id) at time \(randomStartTime)"
      )

      // First pause any current video
      NotificationCenter.default.post(
        name: .videoPlayerShouldSwitch,
        object: nil,
        userInfo: ["pauseOnly": true]
      )

      // Make a direct video switch request
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(
          name: .videoPlayerShouldSwitch,
          object: nil,
          userInfo: [
            "sceneID": self.scene.id,
            "startTime": randomStartTime,
            "forcePlay": true,
          ]
        )

        // Open scene with the app model as well (belt and suspenders)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          // Set fresh UserDefaults values
          UserDefaults.standard.set(randomStartTime, forKey: "last_video_start_time")
          UserDefaults.standard.set(self.scene.id, forKey: "last_scene_id")
          UserDefaults.standard.synchronize()

          // Set app model values and open scene
          self.appModel.videoStartTime = randomStartTime
          self.appModel.selectedSceneStartTime = randomStartTime
          self.appModel.setCurrentScene(self.scene, in: self.allScenes)
          self.appModel.openScene(self.scene, startTime: randomStartTime)

          // Reset flag
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isShuffling = false
          }
        }
      }
    }
  }
}
