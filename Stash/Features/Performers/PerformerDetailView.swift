import SwiftUI

struct PerformerDetailView: View {
  let performer: StashScene.Performer
  @EnvironmentObject private var api: StashAPI
  @EnvironmentObject private var navigationModel: NavigationModel
  @State private var selectedTab = 0
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var visibleMarkers: Set<String> = []

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Header with performer info
        performerHeader

        // Tab picker and content
        tabContent
      }
    }
    .task {
      await loadInitialContent()
    }
  }

  // MARK: - Subviews
  private var performerHeader: some View {
    VStack(spacing: 20) {
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

      Text(performer.name)
        .font(.title)
    }
    .padding(.horizontal)
  }

  private var tabContent: some View {
    VStack {
      // Tab picker
      Picker("Content", selection: $selectedTab) {
        Text("Scenes").tag(0)
        Text("Markers").tag(1)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      // Content
      if selectedTab == 0 {
        scenesGrid
      } else {
        markersGrid
      }
    }
  }

  private var scenesGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
      ForEach(api.scenes) { scene in
        SceneRow(scene: scene, allScenes: api.scenes)
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

  private var markersGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
      ForEach(api.markers) { marker in
        MarkerRow(
          marker: marker,
          isPreviewVisible: visibleMarkers.contains(marker.id),
          onTagSelected: { tag in
            // Navigate to markers with this tag
            navigationModel.navigate(to: Route.tagMarkers(tag))
          }
        )
        .environmentObject(navigationModel)
        .onAppear {
          if visibleMarkers.count < 5 {
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

  // MARK: - Methods
  private func loadInitialContent() async {
    currentPage = 1
    hasMorePages = true
    isLoadingMore = false
    visibleMarkers.removeAll()

    if selectedTab == 0 {
      await api.fetchPerformerScenes(performerId: performer.id)
    } else {
      await api.fetchMarkers(page: currentPage, appendResults: false, performerId: performer.id)
    }
  }

  private func loadMoreScenes() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.scenes.count
    try? await api.fetchScenes()

    isLoadingMore = false
    hasMorePages = api.scenes.count > previousCount
  }

  private func loadMoreMarkers() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.markers.count
    await api.fetchMarkers(page: currentPage, appendResults: true, performerId: performer.id)

    isLoadingMore = false
    hasMorePages = api.markers.count > previousCount
  }
}

struct PerformerDetailView_Previews: PreviewProvider {
  static var previews: some View {
    let api = StashAPI()
    api.preview = true
    return PerformerDetailView(performer: StashScene.Performer.example)
      .environmentObject(api)
      .environmentObject(NavigationModel())
  }
}
