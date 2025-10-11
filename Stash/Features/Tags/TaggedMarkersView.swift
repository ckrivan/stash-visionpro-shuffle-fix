import SwiftUI

struct TaggedMarkersView: View {
  let tag: StashScene.Tag
  @StateObject private var api = StashAPI()
  @State private var markers: [SceneMarker] = []
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var visibleMarkers: Set<String> = []
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      if api.isLoading && markers.isEmpty {
        ProgressView("Loading markers...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if markers.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: "bookmark.slash")
            .font(.system(size: 60))
            .foregroundColor(.secondary)
          Text("No markers found")
            .font(.title2)
          Text("No markers tagged with \(tag.name)")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
            ForEach(markers) { marker in
              MarkerRow(
                marker: marker,
                isPreviewVisible: visibleMarkers.contains(marker.id),
                onTagSelected: { selectedTag in
                  // Navigate to another tag's markers
                  navigationModel.navigate(to: Route.tagMarkers(selectedTag))
                }
              )
              .environmentObject(navigationModel)
              .onAppear {
                if visibleMarkers.count < 5 {
                  visibleMarkers.insert(marker.id)
                }
                if marker == markers.last && !isLoadingMore && hasMorePages {
                  Task {
                    await loadMore()
                  }
                }
              }
              .onDisappear {
                visibleMarkers.remove(marker.id)
              }
            }

            if isLoadingMore {
              ProgressView()
                .padding()
            }
          }
          .padding()
        }
      }
    }
    .navigationTitle("\(tag.name) Markers")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button(action: {
          shuffleRandomMarker()
        }) {
          HStack {
            Image(systemName: "shuffle.circle.fill")
            Text("Shuffle")
          }
          .foregroundColor(.purple)
        }
        .disabled(markers.isEmpty)
      }

      ToolbarItem(placement: .cancellationAction) {
        Button("Done") { dismiss() }
      }
    }
    .task {
      await loadInitial()
    }
  }

  private func loadInitial() async {
    currentPage = 1
    hasMorePages = true
    markers = []
    await loadMarkers()
  }

  private func loadMore() async {
    guard !isLoadingMore && hasMorePages else { return }
    isLoadingMore = true
    currentPage += 1
    await loadMarkers()
    isLoadingMore = false
  }

  private func loadMarkers() async {
    await api.fetchMarkersByTag(
      tagId: tag.id,
      page: currentPage,
      appendResults: true,
      perPage: 40
    )

    // Get markers from API
    let fetchedMarkers = api.markers

    if currentPage == 1 {
      markers = fetchedMarkers
    } else {
      // Check if we got new markers
      let existingIds = Set(markers.map { $0.id })
      let newMarkers = fetchedMarkers.filter { !existingIds.contains($0.id) }

      if newMarkers.isEmpty {
        hasMorePages = false
      } else {
        markers.append(contentsOf: newMarkers)
      }
    }
  }

  private func shuffleRandomMarker() {
    guard !markers.isEmpty else { return }

    print("🎲 Starting marker shuffle for tag: \(tag.name)")

    // Start marker shuffle using the tag
    appModel.startMarkerShuffle(
      forTag: tag.id,
      tagName: tag.name,
      displayedMarkers: markers
    )
  }
}
