import SwiftUI

struct MediaLibraryView: View {
  @StateObject private var api = StashAPI()
  @EnvironmentObject private var navigationModel: NavigationModel
  @State private var selectedScene: StashScene?
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var searchText = ""
  @State private var searchDebounceTask: Task<Void, Never>?
  @State private var showPlayer = false
  @State private var currentFilter: String = "default"

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        MediaLibraryContentView(
          api: api,
          geometry: geometry,
          selectedScene: $selectedScene,
          showPlayer: $showPlayer,
          isLoadingMore: isLoadingMore,
          onDelete: { id in
            api.scenes.removeAll { $0.id == id }
          },
          onSceneTap: { scene in
            selectedScene = scene
            showPlayer = true
            Task {
              do {
                try await api.fetchScenes(page: 1, sort: "random")
              } catch {
                print("Error fetching random scenes: \(error)")
              }
            }
          },
          onSceneAppear: { scene in
            checkIfLoadMore(scene)
          }
        )
      }
      .searchable(text: $searchText)
      .navigationTitle("Media Library")
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: searchText) { newValue in
        handleSearchChange(newValue)
      }
      .refreshable {
        await resetAndReload()
      }
      .toolbar {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
          FilterMenuView(
            currentFilter: $currentFilter,
            onDefaultSelected: {
              Task {
                await resetAndReload()
              }
            },
            onNewestSelected: {
              Task {
                do {
                  try await api.fetchScenes(page: 1, sort: "date")
                } catch {
                  print("Error fetching newest scenes: \(error)")
                }
              }
            },
            onOCounterSelected: {
              Task {
                do {
                  try await api.fetchScenes(page: 1, sort: "o_counter")
                } catch {
                  print("Error fetching scenes by o_counter: \(error)")
                }
              }
            },
            onRandomSelected: {
              Task {
                do {
                  try await api.fetchScenes(page: 1, sort: "random")
                } catch {
                  print("Error fetching random scenes: \(error)")
                }
              }
            },
            onReload: {
              Task {
                await resetAndReload()
              }
            }
          )
        }
      }
      .task {
        if api.scenes.isEmpty && searchText.isEmpty {
          await loadInitialScenes()
        }
      }
      .onAppear {
        onAppear()
      }
    }
    .fullScreenCover(isPresented: $showPlayer) {
      if let scene = selectedScene {
        VideoPlayerView(scene: scene)
          .environmentObject(navigationModel)
      }
    }
  }

  private func loadInitialScenes() async {
    currentPage = 1
    hasMorePages = true
    do {
      // Immediately fetch first page
      try await api.fetchScenes()

      // Pre-fetch the second page in the background
      if hasMorePages {
        Task {
          try? await Task.sleep(nanoseconds: 500_000_000)  // Wait 0.5 seconds before pre-fetching
          await preloadNextPage()
        }
      }
    } catch {
      print("Error loading scenes: \(error)")
    }
  }

  private func preloadNextPage() async {
    guard !isLoadingMore && hasMorePages else { return }

    print("Preloading next page of scenes")
    let tempLoadingFlag = isLoadingMore
    isLoadingMore = true

    let nextPage = currentPage + 1
    let previousCount = api.scenes.count

    do {
      // Fetch the next page but don't update currentPage yet
      try await api.fetchScenes(page: nextPage, appendResults: true)
      print("Preloaded \(api.scenes.count - previousCount) scenes for smooth scrolling")
      hasMorePages = api.scenes.count > previousCount
    } catch {
      print("Error preloading scenes: \(error)")
    }

    // Only update current page if we successfully preloaded data
    if api.scenes.count > previousCount {
      currentPage = nextPage
    }

    isLoadingMore = tempLoadingFlag
  }

  private func resetAndReload() async {
    await loadInitialScenes()
  }

  private func loadMoreScenes() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.scenes.count
    do {
      try await api.fetchScenes()
    } catch {
      print("Error loading more scenes: \(error)")
    }

    isLoadingMore = false
    hasMorePages = api.scenes.count > previousCount
  }

  private func checkIfLoadMore(_ scene: StashScene) {
    // Check if this is one of the last few scenes displayed
    let visibleIndex = api.scenes.firstIndex { $0.id == scene.id } ?? 0
    let threshold = max(0, api.scenes.count - 5)  // Load more when we're 5 items from the end

    if visibleIndex >= threshold && !isLoadingMore && hasMorePages {
      print("Loading more scenes at index \(visibleIndex) of \(api.scenes.count)")
      Task {
        await loadMoreScenes()
      }
    }
  }

  private func handleSearchChange(_ newValue: String) {
    searchDebounceTask?.cancel()
    searchDebounceTask = Task {
      try? await Task.sleep(for: .milliseconds(500))
      if !Task.isCancelled {
        if !newValue.isEmpty {
          print("🔎 Performing search for: \(newValue)")
          // Search with the current query
          await api.searchScenes(query: newValue)
          // Reset page tracking but keep search results
          currentPage = 1
          hasMorePages = true
          isLoadingMore = false

          // Debug print the results count
          print("🔎 Search returned \(api.scenes.count) results")
        } else {
          print("🔎 Search cleared, resetting to default view")
          // Only reset to default view when search is explicitly cleared
          await resetAndReload()
        }
      }
    }
  }

  private func muteAllPreviews() {
    GlobalVideoManager.shared.muteAll()
  }

  private func reloadContent() {
    Task {
      await resetAndReload()
    }
  }

  private func playRandomVideo() {
    // Stop any existing preview audio
    GlobalVideoManager.shared.muteAll()

    Task {
      // Fetch a random scene using the API's random sort
      do {
        try await api.fetchScenes(page: 1, sort: "random")

        // Get the first scene from the random results
        if let randomScene = api.scenes.first {
          selectedScene = randomScene
          showPlayer = true
        }
      } catch {
        print("Error fetching random video: \(error)")
      }
    }
  }

  private func onAppear() {
    // Ensure muting is enforced when view appears
    muteAllPreviews()

    // Only load initial scenes if we don't have any scenes or no search is active
    if api.scenes.isEmpty && searchText.isEmpty {
      Task {
        await loadInitialScenes()
      }
    }
  }

  // Helper function to determine column count based on width
  private func getColumnCount(for width: CGFloat) -> Int {
    if width < 600 {
      return 2  // Very small width, show only 2 columns
    } else if width < 1000 {
      return 3  // Standard width, show 3 columns
    } else if width < 1400 {
      return 4  // Large width, show 4 columns
    } else {
      return 5  // Very large width, show 5 columns
    }
  }
}

struct MediaLibraryContentView: View {
  let api: StashAPI
  let geometry: GeometryProxy
  @Binding var selectedScene: StashScene?
  @Binding var showPlayer: Bool
  let isLoadingMore: Bool
  let onDelete: (String) -> Void
  let onSceneTap: (StashScene) -> Void
  let onSceneAppear: (StashScene) -> Void

  var body: some View {
    ScrollView {
      let columnCount = getColumnCount(for: geometry.size.width)
      let columns = Array(repeating: GridItem(.flexible()), count: columnCount)

      Rectangle()
        .fill(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
          GlobalVideoManager.shared.stopAllPreviews()
        }
        .frame(height: 1)

      LazyVGrid(columns: columns, spacing: 20) {
        ForEach(api.scenes, id: \.id) { scene in
          SceneRow(scene: scene, onDelete: onDelete)
            .frame(maxWidth: .infinity)
            .onTapGesture {
              onSceneTap(scene)
            }
            .onAppear {
              onSceneAppear(scene)
            }
            .task {
              if let screenshotPath = scene.paths.screenshot,
                let url = URL(string: screenshotPath) {
                _ = try? await URLSession.shared.data(from: url)
              }
            }
        }

        if isLoadingMore {
          ProgressView()
            .gridCellColumns(1)
            .padding()
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      GlobalVideoManager.shared.stopAllPreviews()
    }
    .edgesIgnoringSafeArea(.bottom)
  }

  private func getColumnCount(for width: CGFloat) -> Int {
    if width < 600 {
      return 2
    } else if width < 1000 {
      return 3
    } else if width < 1400 {
      return 4
    } else {
      return 5
    }
  }
}

struct FilterMenuView: View {
  @Binding var currentFilter: String
  let onDefaultSelected: () -> Void
  let onNewestSelected: () -> Void
  let onOCounterSelected: () -> Void
  let onRandomSelected: () -> Void
  let onReload: () -> Void

  var body: some View {
    HStack {
      Menu {
        Button(action: {
          currentFilter = "default"
          onDefaultSelected()
        }) {
          Label("Default View", systemImage: "rectangle.grid.2x2")
          if currentFilter == "default" {
            Image(systemName: "checkmark")
          }
        }

        Button(action: {
          currentFilter = "newest"
          onNewestSelected()
        }) {
          Label("Newest", systemImage: "clock")
          if currentFilter == "newest" {
            Image(systemName: "checkmark")
          }
        }

        Button(action: {
          currentFilter = "o_counter"
          onOCounterSelected()
        }) {
          Label("OCounter", systemImage: "number.circle")
          if currentFilter == "o_counter" {
            Image(systemName: "checkmark")
          }
        }

        Button(action: {
          currentFilter = "random"
          onRandomSelected()
        }) {
          Label("Random", systemImage: "shuffle")
          if currentFilter == "random" {
            Image(systemName: "checkmark")
          }
        }
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      Button(action: onReload) {
        Image(systemName: "arrow.clockwise")
      }
    }
  }
}

struct MediaLibraryView_Previews: PreviewProvider {
  static var previews: some View {
    MediaLibraryView()
      .environmentObject(NavigationModel())
      
  }
}
