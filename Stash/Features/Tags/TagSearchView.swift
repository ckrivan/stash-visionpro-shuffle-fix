import Combine
import SwiftUI

struct TagSearchView: View {
  @StateObject private var api = StashAPI()
  @State private var searchText = ""
  @State private var tags: [StashScene.Tag] = []
  @State private var isSearching = false
  @State private var debounceTask: Task<Void, Never>?
  @State private var selectedTag: StashScene.Tag?
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    VStack(spacing: 0) {
      // Search bar at top
      SearchBar(text: $searchText)
        .padding(.horizontal)
        .padding(.top)
        .onChange(of: searchText) { _, newValue in
          debounceSearch(query: newValue)
        }

      // Tags grid
      if isSearching {
        ProgressView("Searching...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if tags.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: searchText.isEmpty ? "tag" : "tag.slash")
            .font(.system(size: 60))
            .foregroundColor(.secondary)
          Text(searchText.isEmpty ? "Search for tags" : "No tags found")
            .font(.title2)
          if !searchText.isEmpty {
            Text("Try a different search term")
              .foregroundColor(.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 12) {
            ForEach(tags) { tag in
              TagButton(tag: tag) {
                navigationModel.navigate(to: Route.tag(tag))
              }
            }
          }
          .padding()
        }
      }
    }
    .navigationTitle("Tag Search")
    .task {
      // Load popular tags on first load
      if tags.isEmpty {
        await loadPopularTags()
      }
    }
  }

  private func loadPopularTags() async {
    isSearching = true
    do {
      let allTags = try await api.fetchTags()

      // Sort by scene count to get most popular first
      let sortedTags = allTags.sorted { ($0.scene_count ?? 0) > ($1.scene_count ?? 0) }

      // Take first 50 tags
      await MainActor.run {
        tags = Array(sortedTags.prefix(50))
        isSearching = false
      }
    } catch {
      print("Error loading popular tags: \(error)")
      await MainActor.run {
        isSearching = false
      }
    }
  }

  private func debounceSearch(query: String) {
    print("🏷️ debounceSearch called with query: '\(query)'")
    // Cancel any previous search task
    debounceTask?.cancel()

    // Create a new search task with delay
    debounceTask = Task {
      print("🏷️ Debounce task started, sleeping 500ms...")
      try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms delay

      guard !Task.isCancelled else {
        print("🏷️ Debounce task was cancelled")
        return
      }

      print("🏷️ Debounce complete, query: '\(query)'")
      if query.isEmpty {
        // Load popular tags if search is cleared
        print("🏷️ Query empty, loading popular tags")
        await loadPopularTags()
      } else {
        // Search for tags
        print("🏷️ Query not empty, searching for tags...")
        await searchTags(query: query)
      }
    }
  }

  private func searchTags(query: String) async {
    guard !query.isEmpty else { return }

    print("🏷️ TagSearchView.searchTags called with query: '\(query)'")
    await MainActor.run {
      isSearching = true
    }

    do {
      print("🏷️ Calling api.searchTags...")
      let results = try await api.searchTags(query: query)
      print("🏷️ API returned \(results.count) tags for query '\(query)'")

      await MainActor.run {
        tags = results
        isSearching = false
        print("🏷️ Updated UI with \(results.count) tags")
      }
    } catch {
      print("❌ Error searching tags: \(error)")
      await MainActor.run {
        isSearching = false
      }
    }
  }
}

struct TagButton: View {
  let tag: StashScene.Tag
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Text(tag.name)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
          .truncationMode(.tail)

        if let sceneCount = tag.scene_count {
          Text("\(sceneCount) scene\(sceneCount == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .padding(.horizontal, 8)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .hoverEffect(.lift)
  }
}

struct TagSearchView_Previews: PreviewProvider {
  static var previews: some View {
    TagSearchView()
      .environmentObject(NavigationModel())
  }
}
