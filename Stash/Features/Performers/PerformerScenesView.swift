import SwiftUI

struct PerformerScenesView: View {
  let performer: StashScene.Performer
  @EnvironmentObject private var navigationModel: NavigationModel
  @EnvironmentObject private var api: StashAPI
  @EnvironmentObject private var appModel: AppModel
  @State private var selectedTab = 0  // 0 for scenes, 1 for markers
  @State private var currentPage = 1
  @State private var hasMoreContent = true
  @State private var isLoadingMore = false
  @State private var sortOption = SortOption.date
  @State private var isJumping = false

  enum SortOption: String, CaseIterable, Identifiable {
    case date = "Date"
    case title = "Title"
    case resolution = "Resolution"

    var id: String { rawValue }

    var apiValue: String {
      switch self {
      case .date: return "date"
      case .title: return "title"
      case .resolution: return "resolution"
      }
    }

    var apiDirection: String {
      switch self {
      case .resolution: return "DESC"  // Higher resolution first
      case .date: return "DESC"  // Newest first
      case .title: return "ASC"  // A to Z
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Performer header
        if let imagePath = performer.image_path,
          let imageURL = URL(string: imagePath)
        {
          AsyncImage(url: imageURL) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Rectangle()
              .fill(.ultraThinMaterial)
          }
          .frame(width: 200, height: 200)
          .clipShape(Circle())
        }

        // Control buttons based on selected tab
        if selectedTab == 0 {
          // Scenes tab controls
          HStack(spacing: 12) {
            Picker("Sort by", selection: $sortOption) {
              ForEach(SortOption.allCases) { option in
                Text(option.rawValue).tag(option)
              }
            }
            .pickerStyle(.menu)
            .onChange(of: sortOption) { _, newValue in
              Task {
                currentPage = 1
                await loadSortedScenes(sort: newValue)
              }
            }

            Button {
              playRandomScene()
            } label: {
              Label("Shuffle Play", systemImage: "shuffle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(api.scenes.isEmpty)

            // Random Jump button
            Button {
              randomJump()
            } label: {
              HStack {
                Image(systemName: "shuffle.circle.fill")
                Text("Random Jump")
              }
              .font(.callout)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            .disabled(api.scenes.isEmpty || isJumping)
          }
        } else {
          // Markers tab controls
          HStack(spacing: 12) {
            // Placeholder for sort options (could be added later)
            Spacer()

            Button {
              startPerformerMarkerShuffle()
            } label: {
              Label("Shuffle Markers", systemImage: "shuffle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(api.markers.isEmpty)

            if !api.markers.isEmpty {
              Text("\(api.markers.count) markers")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        // Tabs
        Picker("View", selection: $selectedTab) {
          Text("Scenes").tag(0)
          Text("Markers").tag(1)
        }
        .pickerStyle(.segmented)

        // Content
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400))], spacing: 20) {
          if api.isLoading && currentPage == 1 {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if selectedTab == 0 {
            // Scenes
            if api.scenes.isEmpty {
              Text("No scenes found")
                .foregroundStyle(.secondary)
            } else {
              ForEach(api.scenes) { scene in
                SceneRow(scene: scene, allScenes: api.scenes)
                  .onAppear {
                    if scene == api.scenes.last && hasMoreContent && !isLoadingMore {
                      Task {
                        await loadMoreScenes()
                      }
                    }
                  }
              }

              if hasMoreContent && !api.scenes.isEmpty && !api.isLoading {
                ProgressView()
                  .onAppear {
                    Task {
                      await loadMoreScenes()
                    }
                  }
              }
            }
          } else {
            // Markers
            if api.markers.isEmpty {
              Text("No markers found")
                .foregroundStyle(.secondary)
            } else {

              ForEach(api.markers) { marker in
                MarkerRow(
                  marker: marker,
                  isPreviewVisible: true,
                  onTagSelected: { tag in
                    // Navigate to markers with this tag
                    navigationModel.navigate(to: Route.tagMarkers(tag))
                  }
                )
                .environmentObject(navigationModel)
              }

              if hasMoreContent {
                ProgressView()
                  .onAppear {
                    Task {
                      currentPage += 1
                      await loadMoreMarkers()
                    }
                  }
              }
            }
          }
        }
      }
      .padding()
    }
    .navigationTitle(performer.name)
    .task {
      await loadInitialContent()
    }
    .onChange(of: selectedTab) { _, newValue in
      Task {
        currentPage = 1
        hasMoreContent = true
        isLoadingMore = false
        if newValue == 0 {
          await loadSortedScenes(sort: sortOption)
        } else {
          do {
            try await api.fetchPerformerMarkers(performerId: performer.id, page: currentPage)
          } catch {
            print("Error fetching performer markers: \(error)")
          }
        }
      }
    }
  }

  private func playRandomScene() {
    guard let randomScene = api.scenes.randomElement() else {
      print("⚠️ No scenes available for random play")
      return
    }

    print(
      "🎲 Selected random scene for regular playback: \(randomScene.id) - \(randomScene.title ?? "Untitled")"
    )

    // Use aggressive audio cleanup to prevent any echoing
    GlobalVideoManager.shared.forceStopAllAudio()

    // Ensure we have a valid stream URL
    guard let streamURL = randomScene.paths.stream, !streamURL.isEmpty else {
      print("⚠️ No stream URL found for scene \(randomScene.id)")
      return
    }

    Task {
      // Significant delay to ensure audio system is fully reset
      try await Task.sleep(nanoseconds: 500_000_000)  // 500ms
      print("🔊 Audio system reset pause complete")

      // Additional cleanup for safety
      GlobalVideoManager.shared.stopAllPreviews()

      await MainActor.run {
        // Clear any existing scene to prevent old audio from persisting
        if appModel.currentScene != nil {
          appModel.currentScene = nil
        }

        // Reset any previous player state
        appModel.isShowingPlayer = false

        // Set selected scene and start playing from beginning
        appModel.selectedScene = randomScene

        // Explicitly set start time to beginning
        appModel.videoStartTime = 0
        appModel.selectedSceneStartTime = nil

        // Clear any previous start time in UserDefaults
        UserDefaults.standard.removeObject(forKey: "last_video_start_time")
        UserDefaults.standard.set(randomScene.id, forKey: "last_scene_id")
      }

      // Another brief pause
      try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

      await MainActor.run {
        print("🎬 Playing random scene from beginning: \(randomScene.id)")

        // Set scene context for navigation
        appModel.setCurrentScene(randomScene, in: api.scenes)
        // Open scene first, then set player flag
        appModel.openScene(randomScene)
        appModel.isShowingPlayer = true
      }
    }
  }

  private func startPerformerMarkerShuffle() {
    print("🎲 Starting performer marker shuffle for \(performer.name)")
    appModel.startMarkerShuffle(forPerformer: performer, displayedMarkers: api.markers)
  }

  private func loadMoreScenes() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.scenes.count
    await fetchScenes(page: currentPage, appendResults: true)

    // Check if we got more scenes
    let newCount = api.scenes.count
    hasMoreContent = newCount > previousCount

    print(
      "📊 Loaded more scenes - previous: \(previousCount), new: \(newCount), hasMore: \(hasMoreContent)"
    )
    isLoadingMore = false
  }

  private func loadMoreMarkers() async {
    do {
      try await api.fetchPerformerMarkers(performerId: performer.id, page: currentPage)
    } catch {
      print("Error loading more markers: \(error)")
    }
    // If we got less than perPage items, we've reached the end
    if api.markers.count < currentPage * 20 {
      hasMoreContent = false
    }
  }

  private func loadInitialContent() async {
    currentPage = 1
    hasMoreContent = true
    isLoadingMore = false

    // Add debugging to identify performer
    print("🔍 PerformerScenesView loading content for: \(performer.name) with ID: \(performer.id)")

    // Reset the total scene count when initializing
    await MainActor.run {
      api.totalSceneCount = 0
    }

    if selectedTab == 0 {
      await loadSortedScenes(sort: sortOption)
    } else {
      do {
        try await api.fetchPerformerMarkers(performerId: performer.id, page: currentPage)
      } catch {
        print("Error fetching performer markers: \(error)")
      }
    }
  }

  private func loadSortedScenes(sort: SortOption) async {
    currentPage = 1
    await fetchScenes(page: 1, appendResults: false)
  }

  private func fetchScenes(page: Int, appendResults: Bool) async {
    // Add more debugging to see performer ID at fetch time
    print("🔍 fetchScenes for performer: \(performer.name) with ID: \(performer.id) - page \(page)")

    // For resolution sorting, we need a custom implementation
    if sortOption == .resolution {
      // First check if we need to fetch all scenes from the beginning
      if !appendResults || page == 1 {
        // Get the total scene count from the API first to determine if we need a special approach
        await fetchTotalSceneCount()

        // Handle large collections by loading as many scenes as possible in one go
        let totalScenes = api.totalSceneCount

        if totalScenes > 40 {
          print(
            "⚠️ Large collection detected with \(totalScenes) total scenes. Using special fetching approach."
          )

          // Set a higher perPage value to capture more scenes in fewer network requests
          // Most APIs allow 500-1000 items per page, adjust based on server limits
          let maxPerPage = 500

          // Calculate how many pages we need to fetch
          let totalPages = Int(ceil(Double(totalScenes) / Double(maxPerPage)))

          // Fetch all pages to get the complete collection for filtering
          for pageNum in 1...totalPages {
            // Clear results on first page only
            let shouldAppend = pageNum > 1

            print(
              "🔄 Fetching resolution filter page \(pageNum) of \(totalPages) with \(maxPerPage) items per page"
            )

            await api.fetchPerformerScenes(
              performerId: performer.id,
              page: pageNum,
              perPage: maxPerPage,
              sort: "date",  // Use consistent sort for fetching
              direction: "DESC",
              appendResults: shouldAppend
            )
          }

          // Sort all scenes by resolution after fetching everything
          await MainActor.run {
            api.scenes.sort { scene1, scene2 -> Bool in
              let res1 = getMaxResolution(scene1)
              let res2 = getMaxResolution(scene2)
              return res1 > res2  // Higher resolution first
            }

            print("✅ Sorted \(api.scenes.count) scenes by resolution")
          }

          return
        }

        // For smaller collections, use the original approach
        await api.fetchPerformerScenes(
          performerId: performer.id,
          page: page,
          perPage: 100,  // Fetch more to have enough to sort
          sort: "date",  // Default sort
          direction: "DESC",
          appendResults: appendResults
        )

        // Then sort them locally by resolution
        await MainActor.run {
          api.scenes.sort { scene1, scene2 -> Bool in
            let res1 = getMaxResolution(scene1)
            let res2 = getMaxResolution(scene2)
            return res1 > res2  // Higher resolution first
          }
        }
      } else {
        // For pagination after initial sort, just fetch more (which won't affect our manually sorted list)
        await api.fetchPerformerScenes(
          performerId: performer.id,
          page: page,
          perPage: 100,
          sort: "date",
          direction: "DESC",
          appendResults: true
        )
      }
    } else {
      // For other sorts, use the API's sorting
      await api.fetchPerformerScenes(
        performerId: performer.id,
        page: page,
        perPage: 40,
        sort: sortOption.apiValue,
        direction: sortOption.apiDirection,
        appendResults: appendResults
      )
    }
  }

  // Helper method to get the total scene count for a performer
  private func fetchTotalSceneCount() async {
    guard api.totalSceneCount == 0 else { return }

    // Add logging of performer ID here too
    print("🔍 fetchTotalSceneCount for performer: \(performer.name) with ID: \(performer.id)")

    // Make a simple query that only requests the count
    let query = """
      {
          "operationName": "FindScenes",
          "variables": {
              "filter": {
                  "page": 1,
                  "per_page": 1
              },
              "scene_filter": {
                  "performers": {
                      "modifier": "INCLUDES",
                      "value": ["\(performer.id)"]
                  }
              }
          },
          "query": "query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) { findScenes(filter: $filter, scene_filter: $scene_filter) { count scenes { id } } }"
      }
      """

    do {
      let data = try await api.executeGraphQLQuery(query)

      // Parse the response to get the count
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let data = json["data"] as? [String: Any],
        let findScenes = data["findScenes"] as? [String: Any],
        let count = findScenes["count"] as? Int
      {
        await MainActor.run {
          api.totalSceneCount = count
          print("📊 Total scenes for performer: \(count)")
        }
      }
    } catch {
      print("❌ Error fetching total scene count: \(error)")
    }
  }

  private func getMaxResolution(_ scene: StashScene) -> Int {
    // Calculate resolution as width × height
    guard let files = scene.files, !files.isEmpty else { return 0 }

    let resolutions = files.compactMap { file -> Int? in
      guard let width = file.width, let height = file.height else { return nil }
      return width * height
    }

    return resolutions.max() ?? 0
  }

  private func randomJump() {
    guard !isJumping, !api.scenes.isEmpty else { return }
    isJumping = true

    // Force thorough audio cleanup
    GlobalVideoManager.shared.forceStopAllAudio()

    Task {
      do {
        // Introduce a significant delay to ensure audio system is fully reset
        // This is critical to prevent audio duplication
        try await Task.sleep(nanoseconds: 500_000_000)  // 500ms
        print("🔊 Audio system reset pause complete")

        // Additional cleanup for safety
        GlobalVideoManager.shared.stopAllPreviews()

        // Get a random scene from the current list
        guard let randomScene = api.scenes.randomElement() else {
          print("⚠️ No scenes available for random jump")
          await MainActor.run {
            isJumping = false
          }
          return
        }

        print("🎲 Selected random scene: \(randomScene.id) - \(randomScene.title ?? "Untitled")")

        // Generate a random position between 10% and 90% of the duration
        var startTime: Double = 0
        if let duration = randomScene.files?.first?.duration, duration > 10 {
          // Calculate a random position, avoiding very beginning and end
          let minPos = max(10, duration * 0.1)  // Start at least 10 seconds in or 10% in
          let maxPos = min(duration - 20, duration * 0.9)  // End at least 20 seconds from the end or 10% from the end

          // Generate fresh random value
          let randomValue = Double.random(in: minPos...maxPos)
          startTime = randomValue

          print(
            "🎲 Generated random start time: \(startTime) seconds (within range \(minPos) to \(maxPos) of total \(duration))"
          )
        } else {
          print("⚠️ No duration info available for scene \(randomScene.id), starting from beginning")
          startTime = 0
        }

        // Ensure we have a valid stream URL
        guard let streamURL = randomScene.paths.stream, !streamURL.isEmpty else {
          print("⚠️ No stream URL found for scene \(randomScene.id)")
          await MainActor.run {
            isJumping = false
          }
          return
        }

        // Short delay to ensure audio is fully stopped
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Set start time in the app model and save to UserDefaults
        await MainActor.run {
          print(
            "🎬 Setting random jump start time: \(startTime) seconds for scene: \(randomScene.id)")

          // Clear any existing scene to prevent old audio persisting
          if appModel.currentScene != nil {
            appModel.currentScene = nil
          }

          // Make sure both time values are explicitly set
          appModel.videoStartTime = startTime
          appModel.selectedSceneStartTime = startTime

          // Reset any other player-related state
          appModel.isShowingPlayer = false

          // Persist values to UserDefaults
          UserDefaults.standard.set(startTime, forKey: "last_video_start_time")
          UserDefaults.standard.set(randomScene.id, forKey: "last_scene_id")
          UserDefaults.standard.synchronize()
        }

        // Short delay to ensure values are set
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // Open the scene with the random start time
        await MainActor.run {
          // Set scene context for navigation
          appModel.setCurrentScene(randomScene, in: api.scenes)
          // This will handle cleanup and setup of the player
          appModel.openScene(randomScene, startTime: startTime)

          // Explicitly set isShowingPlayer to ensure the player appears
          appModel.isShowingPlayer = true

          print("🎬 Opening scene \(randomScene.id) at position \(startTime) seconds")
        }

        // Wait to ensure the player is initialized before resetting the jumping flag
        try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms

        await MainActor.run {
          print("✅ Random jump complete")
          isJumping = false
        }
      } catch {
        print("❌ Error during random jump: \(error)")
        await MainActor.run {
          isJumping = false
        }
      }
    }
  }
}

// MARK: - Supporting Views

private struct PerformerHeader: View {
  let performer: StashScene.Performer

  var body: some View {
    if let imagePath = performer.image_path,
      let imageURL = URL(string: imagePath)
    {
      AsyncImage(url: imageURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(.ultraThinMaterial)
      }
      .frame(width: 200, height: 200)
      .clipShape(Circle())
      .padding(.vertical)
    }
  }
}

private struct TabSelector: View {
  @Binding var selectedTab: Int

  var body: some View {
    Picker("View", selection: $selectedTab) {
      Text("Scenes").tag(0)
      Text("Markers").tag(1)
    }
    .pickerStyle(.segmented)
    .padding()
  }
}

private struct TabContent: View {
  let selectedTab: Int
  let api: StashAPI
  let performer: StashScene.Performer

  var body: some View {
    TabView(selection: .constant(selectedTab)) {
      ScenesTab(api: api)
        .tag(0)

      MarkersTab(api: api)
        .tag(1)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .onChange(of: selectedTab) { _, newValue in
      Task {
        if newValue == 0 {
          do {
            try await api.fetchPerformerScenes(performerId: performer.id)
          } catch {
            print("Error fetching performer scenes: \(error)")
          }
        } else {
          do {
            try await api.fetchPerformerMarkers(performerId: performer.id)
          } catch {
            print("Error fetching performer markers: \(error)")
          }
        }
      }
    }
  }
}

private struct ScenesTab: View {
  let api: StashAPI

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
        if api.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if api.scenes.isEmpty {
          Text("No scenes found")
            .foregroundStyle(.secondary)
        } else {
          ForEach(api.scenes) { scene in
            SceneRow(scene: scene)
          }
        }
      }
      .padding()
    }
  }
}

private struct MarkersTab: View {
  let api: StashAPI
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
        if api.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if api.markers.isEmpty {
          Text("No markers found")
            .foregroundStyle(.secondary)
        } else {
          ForEach(api.markers) { marker in
            MarkerRow(
              marker: marker,
              isPreviewVisible: true,
              onTagSelected: { tag in
                // Navigate to markers with this tag
                navigationModel.navigate(to: Route.tagMarkers(tag))
              }
            )
            .environmentObject(navigationModel)
          }
        }
      }
      .padding()
    }
  }
}

struct PerformerScenesView_Previews: PreviewProvider {
  static var previews: some View {
    PerformerScenesView(performer: StashScene.Performer.example)
      .environmentObject(NavigationModel())
      .environmentObject(StashAPI())

  }
}
