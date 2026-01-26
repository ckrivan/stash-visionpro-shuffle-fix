import SwiftUI

// MARK: - Main View
struct PerformerMarkersView: View {
  let performer: StashScene.Performer
  @StateObject private var api = StashAPI()
  @StateObject private var navigationModel = NavigationModel()
  @EnvironmentObject private var appModel: AppModel
  @State private var searchText = ""
  @State private var selectedTab = 0
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var visibleMarkers: Set<String> = []

  var body: some View {
    VStack(spacing: 0) {
      // Search bar and tab picker
      searchAndTabView

      // Content
      TabView(selection: $selectedTab) {
        scenesTab
        markersTab
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
    .navigationTitle(performer.name)
    .task {
      await loadInitialContent()
    }
    .onChange(of: searchText) { _, newValue in
      Task {
        await handleSearch(query: newValue)
      }
    }
  }

  // MARK: - Subviews
  private var searchAndTabView: some View {
    VStack {
      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)
        TextField("Search...", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding()
      .background(.ultraThinMaterial)

      // Tab picker
      Picker("Content", selection: $selectedTab) {
        Text("Scenes").tag(0)
        Text("Markers").tag(1)
      }
      .pickerStyle(.segmented)
      .padding()
    }
  }

  private var scenesTab: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
        ForEach(api.scenes) { scene in
          SceneRow(scene: scene)
            .onAppear {
              if scene == api.scenes.last && !isLoadingMore && hasMorePages {
                Task {
                  await loadMoreScenes()
                }
              }
            }
        }
      }
      .padding()
    }
    .tag(0)
  }

  private var markersTab: some View {
    VStack(spacing: 0) {
      // Shuffle button for performer markers
      HStack {
        Button(action: { startPerformerMarkerShuffle() }) {
          HStack {
            Image(systemName: "shuffle")
            Text("Shuffle \(performer.name) Markers")
          }
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.red, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(api.markers.isEmpty)
        .opacity(api.markers.isEmpty ? 0.6 : 1.0)

        if api.markers.isEmpty {
          Text("Loading markers...")
            .foregroundColor(.secondary)
            .font(.caption)
        } else {
          Text("\(api.markers.count) markers")
            .foregroundColor(.secondary)
            .font(.caption)
        }

        Spacer()
      }
      .padding(.horizontal)
      .padding(.bottom, 8)

      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400))], spacing: 20) {
          ForEach(api.markers) { marker in
            MarkerRow(
              marker: marker,
              isPreviewVisible: visibleMarkers.contains(marker.id),
              onTagSelected: { _ in }  // No-op since we don't need tag filtering in this view
            )
            .environmentObject(navigationModel)
            .onAppear {
              if visibleMarkers.count < 10 {
                visibleMarkers.insert(marker.id)
              }
              if marker == api.markers.last && !isLoadingMore && hasMorePages {
                Task {
                  await loadMoreMarkers()
                }
              }
            }
            .onDisappear {
              visibleMarkers.remove(marker.id)
            }
          }
        }
        .padding()
      }
    }
    .tag(1)
  }

  // MARK: - Methods

  private func startPerformerMarkerShuffle() {
    print("🎲 Starting performer marker shuffle for \(performer.name)")
    appModel.startMarkerShuffle(forPerformer: performer, displayedMarkers: api.markers)
  }
  private func handleSearch(query: String) async {
    if query.isEmpty {
      await loadInitialContent()
    } else {
      do {
        if selectedTab == 0 {
          try await api.fetchPerformerScenes(performerId: performer.id)
        } else {
          try await api.fetchPerformerMarkers(performerId: performer.id)
        }
      } catch {
        print("Error handling search: \(error)")
      }
    }
  }

  private func loadInitialContent() async {
    currentPage = 1
    hasMorePages = true
    isLoadingMore = false
    visibleMarkers.removeAll()

    do {
      if selectedTab == 0 {
        // Load performer scenes
        try await api.fetchPerformerScenes(performerId: performer.id)
      } else {
        // Load performer markers
        try await api.fetchPerformerMarkers(performerId: performer.id)
      }
    } catch {
      print("Error loading initial content: \(error)")
    }
  }

  private func loadMoreScenes() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.scenes.count
    do {
      try await api.fetchPerformerScenes(performerId: performer.id, page: currentPage)
    } catch {
      print("Error loading more scenes: \(error)")
    }

    isLoadingMore = false
    hasMorePages = api.scenes.count > previousCount
  }

  private func loadMoreMarkers() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.markers.count
    do {
      try await api.fetchPerformerMarkers(performerId: performer.id, page: currentPage)
    } catch {
      print("Error loading more markers: \(error)")
    }

    isLoadingMore = false
    hasMorePages = api.markers.count > previousCount
  }
}

struct PerformerMarkersView_Previews: PreviewProvider {
  static var previews: some View {
    PerformerMarkersView(performer: StashScene.Performer.example)
      .environmentObject(NavigationModel())
      .environmentObject(AppModel.shared)
  }
}
