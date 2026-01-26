import Foundation
import SwiftUI

struct MarkersView: View {
  // Dependencies
  @EnvironmentObject private var appModel: AppModel

  // State for loading
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true
  @State private var allMarkers: [SceneMarker] = []
  @State private var isLoading = false

  // Track pages for each tag in multi-tag mode
  @State private var multiTagPages: [String: Int] = [:]

  // State for filtering and UI
  @State private var selectedTagId: String?
  @State private var selectedTagIds: Set<String> = []
  @State private var isMultiTagMode: Bool = false
  @State private var showingTagSelector = false
  @State private var availableTags: [StashScene.Tag] = []
  @State private var showingCreateMarker = false
  @State private var visibleMarkers: Set<String> = []
  @State private var displayedMarkers: [SceneMarker] = []

  private func hasPrimaryTag(_ marker: SceneMarker, tagId: String) -> Bool {
    return marker.primary_tag?.id == tagId
  }

  private func hasTag(_ marker: SceneMarker, tagId: String) -> Bool {
    if let tags = marker.tags {
      for tag in tags {
        if tag.id == tagId {
          return true
        }
      }
    }
    return false
  }

  private func shouldIncludeMarker(_ marker: SceneMarker, tagId: String) -> Bool {
    return hasPrimaryTag(marker, tagId: tagId) || hasTag(marker, tagId: tagId)
  }

  private func shouldIncludeMarkerMultiTag(_ marker: SceneMarker, tagIds: Set<String>) -> Bool {
    guard !tagIds.isEmpty else { return true }

    // Check if marker has ANY of the selected tags
    if let primaryTag = marker.primary_tag, tagIds.contains(primaryTag.id) {
      return true
    }
    if let tags = marker.tags {
      return tags.contains { tagIds.contains($0.id) }
    }
    return false
  }

  private func extractAvailableTags() {
    var tags = Set<StashScene.Tag>()

    for marker in allMarkers {
      if let primaryTag = marker.primary_tag {
        tags.insert(
          StashScene.Tag(
            id: primaryTag.id, name: primaryTag.name, scene_count: 0, image_count: 0,
            scene_marker_count: 0))
      }
      if let markerTags = marker.tags {
        for tag in markerTags {
          tags.insert(
            StashScene.Tag(
              id: tag.id, name: tag.name, scene_count: 0, image_count: 0, scene_marker_count: 0))
        }
      }
    }

    availableTags = Array(tags).sorted { $0.name < $1.name }
    print("📊 extractAvailableTags: Found \(availableTags.count) unique tags")
  }

  private func updateDisplayedMarkers() {
    if isMultiTagMode && !selectedTagIds.isEmpty {
      // OR logic: include markers that have ANY of the selected tags (client-side filtering now)
      displayedMarkers = allMarkers.filter { marker in
        guard let tags = marker.tags else { return false }
        return tags.contains { t in selectedTagIds.contains(t.id) }
          || (marker.primary_tag != nil && selectedTagIds.contains(marker.primary_tag!.id))
      }
      print(
        "🔍 Multi-tag OR filter: \(selectedTagIds.count) tags selected, \(displayedMarkers.count) markers shown"
      )
    } else if let tagId = selectedTagId {
      // Filter markers by single selected tag
      displayedMarkers = allMarkers.filter { marker in
        shouldIncludeMarker(marker, tagId: tagId)
      }
    } else {
      // Show all markers
      displayedMarkers = allMarkers
    }

    // Enhanced logging for debugging
    print(
      "🔍 updateDisplayedMarkers: allMarkers=\(allMarkers.count), displayedMarkers=\(displayedMarkers.count), selectedTagId=\(selectedTagId ?? "nil"), multiTagMode=\(isMultiTagMode)"
    )
  }

  private var filterHeader: some View {
    Group {
      if let selectedTagId = selectedTagId,
        let marker = displayedMarkers.first(where: {
          $0.primary_tag?.id == selectedTagId
            || ($0.tags?.contains(where: { $0.id == selectedTagId }) ?? false)
        }),
        let tagName =
          (marker.primary_tag?.id == selectedTagId
            ? marker.primary_tag?.name
            : marker.tags?.first(where: { $0.id == selectedTagId })?.name)
      {
        HStack {
          Text("Filtered by tag: \(tagName)")
          Button(action: clearFilter) {
            Image(systemName: "xmark.circle.fill")
          }
        }
        .padding(.horizontal)
      }
    }
  }

  // MARK: - Enhanced UI Helper Methods

  private var selectedTagText: String {
    if isMultiTagMode {
      return selectedTagIds.isEmpty ? "Select Tags" : "\(selectedTagIds.count) tags"
    } else if let tagId = selectedTagId,
      let tag = availableTags.first(where: { $0.id == tagId })
    {
      return tag.name
    } else {
      return "All Tags"
    }
  }

  private var adaptiveColumns: [GridItem] {
    return [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)]
  }

  private var markerGrid: some View {
    // Use adaptive columns to match the rest of the app's aesthetic
    return LazyVGrid(columns: adaptiveColumns, spacing: 20) {
      ForEach(displayedMarkers, id: \.id) { marker in
        MarkerRow(
          marker: marker,
          isPreviewVisible: visibleMarkers.contains(marker.id),
          onTagSelected: handleTagSelection
        )
        .environmentObject(NavigationModel())
        .frame(maxWidth: .infinity)
        .onAppear {
          visibleMarkers.insert(marker.id)
          checkLoadMore(marker)
        }
        .onDisappear {
          visibleMarkers.remove(marker.id)
        }
        // Add async image prefetching to improve performance
        .task {
          if let screenshotURL = URL(string: "\(marker.screenshot)?apikey=\(appModel.api.apiKey)") {
            // Prefetch the thumbnail image
            _ = try? await URLSession.shared.data(from: screenshotURL)
          }
        }
      }

      if isLoadingMore {
        ProgressView()
          .frame(height: 50)
          .padding()
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func clearFilter() {
    selectedTagId = nil
    selectedTagIds.removeAll()
    updateDisplayedMarkers()
  }

  private func handleTagSelection(_ tag: StashScene.Tag) {
    if isMultiTagMode {
      if selectedTagIds.contains(tag.id) {
        selectedTagIds.remove(tag.id)
      } else {
        selectedTagIds.insert(tag.id)
      }
      Task {
        if isMultiTagMode && !selectedTagIds.isEmpty {
          await fetchMarkersForMultiTagSelection()
        } else {
          updateDisplayedMarkers()
        }
      }
    } else {
      selectedTagId = tag.id
      updateDisplayedMarkers()
    }
  }

  /// Start universal shuffle with all currently displayed markers
  /// For multi-tag mode, shuffle uses custom weighted randomization over tags:
  /// - Group markers by tag.
  /// - When choosing next marker, randomly pick a tag (equal chance).
  /// - Randomly pick a marker from that tag's group excluding already chosen markers.
  /// - Repeat until all markers are exhausted.
  private func startUniversalShuffle() {
    print("🎲 Starting universal shuffle with \(displayedMarkers.count) markers")
    print("🎲 Selected tags: \(selectedTagIds), single tag: \(selectedTagId?.description ?? "none")")

    if !selectedTagIds.isEmpty {
      // Use API-based equal distribution shuffle for multiple tags
      let tagNames = selectedTagIds.compactMap { tagId in
        availableTags.first { $0.id == tagId }?.name
      }
      print("🎲 Starting API-based multi-tag shuffle with equal distribution for: \(tagNames)")
      appModel.startMarkerShuffle(
        forMultipleTags: Array(selectedTagIds), tagNames: tagNames,
        displayedMarkers: displayedMarkers)

    } else if let selectedTagId = selectedTagId,
      let tag = availableTags.first(where: { $0.id == selectedTagId })
    {
      print("🎲 Starting API-based single-tag shuffle for: \(tag.name)")
      appModel.startMarkerShuffle(
        forTag: selectedTagId, tagName: tag.name, displayedMarkers: displayedMarkers)
    } else if !appModel.searchQuery.isEmpty {
      print("🎲 Starting API-based search shuffle for: \(appModel.searchQuery)")
      appModel.startMarkerShuffle(
        forSearchQuery: appModel.searchQuery, displayedMarkers: displayedMarkers)
    } else {
      print("🎲 Starting API-based all markers shuffle")
      appModel.startMarkerShuffle(forSearchQuery: "All Markers", displayedMarkers: displayedMarkers)
    }
  }

  /// Generates a custom shuffle queue implementing weighted randomization by tags:
  /// - groupedMarkers: dictionary where keys are tag IDs and values are arrays of markers for that tag.
  /// - The shuffle picks a tag at random (equal chance) then picks a marker from that tag's group (excluding already chosen markers).
  /// - Continues until all markers are included.
  /// - Returns a list of markers shuffled using this weighted approach.
  private func generateWeightedRandomizedShuffleQueue(groupedMarkers: [String: [SceneMarker]])
    -> [SceneMarker]
  {
    // Copy marker arrays for mutation
    var mutableGroups = groupedMarkers.mapValues { $0.shuffled() }
    // Result queue
    var resultQueue: [SceneMarker] = []
    // Keep track of which markers have been added to avoid duplicates
    var addedMarkers = Set<String>()

    // Flatten all markers for quick check of total count
    let totalMarkersCount = Set(groupedMarkers.values.flatMap { $0 }).count

    // Get list of tag keys for random selection
    var tagKeys = Array(mutableGroups.keys)

    while addedMarkers.count < totalMarkersCount {
      if tagKeys.isEmpty {
        break
      }

      // Randomly select a tag index
      let randomTagIndex = Int.random(in: 0..<tagKeys.count)
      let tagId = tagKeys[randomTagIndex]

      // Access the group's array of markers
      if var markersForTag = mutableGroups[tagId], !markersForTag.isEmpty {
        // Pick the first marker (already shuffled)
        let candidate = markersForTag.removeFirst()
        mutableGroups[tagId] = markersForTag

        if !addedMarkers.contains(candidate.id) {
          resultQueue.append(candidate)
          addedMarkers.insert(candidate.id)
        }

        // If after removing, group's empty, remove tag from keys so it won't be picked again
        if markersForTag.isEmpty {
          tagKeys.remove(at: randomTagIndex)
        }
      } else {
        // No markers for this tag, remove tag key
        tagKeys.remove(at: randomTagIndex)
      }
    }

    return resultQueue
  }

  private func trackVisibleMarker(_ marker: SceneMarker) {
    visibleMarkers.insert(marker.id)
  }

  private func performSearch(_ query: String) {
    Task {
      if query.isEmpty {
        // Show all markers
        await initialLoad()
      } else if query.hasPrefix("_") {
        // Pattern search for suffix
        let suffix = String(query.dropFirst())
        await appModel.api.searchMarkersBySuffix(suffix: suffix)
        allMarkers = appModel.api.markers
        updateDisplayedMarkers()
        extractAvailableTags()
      } else {
        // Regular text search
        await appModel.api.updateMarkersFromSearch(query: query)
        allMarkers = appModel.api.markers
        updateDisplayedMarkers()
        extractAvailableTags()
      }
    }
  }

  private func extractTagsFromMarkers() {
    var tags: Set<StashScene.Tag> = []

    for marker in displayedMarkers {
      if let primaryTag = marker.primary_tag {
        tags.insert(primaryTag)
      }
      if let markerTags = marker.tags {
        for tag in markerTags {
          tags.insert(tag)
        }
      }
    }

    availableTags = Array(tags).sorted { $0.name < $1.name }
  }

  private func checkLoadMore(_ marker: SceneMarker) {
    // Check if this is one of the last few markers displayed
    let visibleIndex = displayedMarkers.firstIndex { $0.id == marker.id } ?? 0
    let threshold = max(0, displayedMarkers.count - 5)  // Load more when we're 5 items from the end

    if visibleIndex >= threshold && !isLoadingMore && hasMorePages {
      print("Loading more markers at index \(visibleIndex) of \(displayedMarkers.count)")
      Task {
        await loadMoreMarkers()
      }
    }
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          // Search and filter controls
          VStack(spacing: 12) {
            // Search bar
            SearchBar(text: $appModel.searchQuery)
              .onChange(of: appModel.searchQuery) { _, newValue in
                performSearch(newValue)
              }

            // Tag filter controls
            HStack(spacing: 12) {
              // Tag filter button
              Button(action: { showingTagSelector = true }) {
                HStack {
                  Image(systemName: "tag")
                  Text(selectedTagText)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
              }

              // Multi-tag mode toggle
              Button(action: { isMultiTagMode.toggle() }) {
                HStack {
                  Image(systemName: isMultiTagMode ? "checkmark.square" : "square")
                  Text("Multi-tag")
                }
                .foregroundColor(isMultiTagMode ? .blue : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
              }

              // Shuffle button
              if !displayedMarkers.isEmpty {
                Button(action: startUniversalShuffle) {
                  HStack {
                    Image(systemName: "shuffle")
                    Text("Shuffle All")
                  }
                  .foregroundColor(.white)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(.red, in: RoundedRectangle(cornerRadius: 8))
                }
              }

              // Show tag weights info if in shuffle mode with tags
              if appModel.isMarkerShuffleMode && !appModel.shuffleTagIds.isEmpty {
                HStack(spacing: 6) {
                  Image(systemName: "equal.square")
                    .foregroundColor(.secondary)
                  Text("Equal shuffle active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .help("Each tag gets equal representation in shuffle")
              }

              Spacer()
            }
            .padding(.horizontal)

            // Multi-tag selection display
            if isMultiTagMode && !selectedTagIds.isEmpty {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                  ForEach(Array(selectedTagIds), id: \.self) { tagId in
                    if let tag = availableTags.first(where: { $0.id == tagId }) {
                      Button(action: {
                        selectedTagIds.remove(tagId)
                        Task {
                          if isMultiTagMode && !selectedTagIds.isEmpty {
                            await fetchMarkersForMultiTagSelection()
                          } else {
                            updateDisplayedMarkers()
                          }
                        }
                      }) {
                        HStack {
                          Text(tag.name)
                          Image(systemName: "xmark.circle.fill")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                        .foregroundColor(.white)
                      }
                    }
                  }
                }
                .padding(.horizontal)
              }
            }
          }
          .padding(.top)
          .background(.ultraThinMaterial)

          // Content area
          if isLoading && displayedMarkers.isEmpty {
            VStack {
              ProgressView()
              Text("Loading markers...")
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if displayedMarkers.isEmpty {
            VStack {
              Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
              Text("No markers found")
                .font(.headline)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            ScrollView(.vertical, showsIndicators: false) {
              LazyVGrid(columns: adaptiveColumns, spacing: 20) {
                ForEach(displayedMarkers, id: \.id) { marker in
                  MarkerRow(
                    marker: marker,
                    isPreviewVisible: visibleMarkers.contains(marker.id),
                    onTagSelected: handleTagSelection
                  )
                  .onAppear {
                    trackVisibleMarker(marker)
                    checkLoadMore(marker)
                  }
                  .onDisappear {
                    visibleMarkers.remove(marker.id)
                  }
                }

                if isLoadingMore && hasMorePages {
                  ProgressView("Loading more...")
                    .frame(maxWidth: .infinity)
                    .padding()
                }
              }
              .padding()
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Markers")
      .navigationBarTitleDisplayMode(.large)
      .sheet(isPresented: $showingTagSelector) {
        TagSelectorSheet(
          availableTags: availableTags,
          selectedTagIds: $selectedTagIds,
          selectedTagId: $selectedTagId,
          isMultiTagMode: $isMultiTagMode
        ) {
          Task {
            await fetchMarkersForMultiTagSelection()
          }
        }
      }
      .task {
        if displayedMarkers.isEmpty {
          await initialLoad()
        }
      }
    }
  }

  private func initialLoad() async {
    print("📊 MarkersView initialLoad started")
    isLoading = true
    currentPage = 1
    hasMorePages = true
    allMarkers = []
    visibleMarkers.removeAll()
    selectedTagId = nil
    multiTagPages = [:]

    // Debug: Print server connection information
    print("📊 MarkersView server address: \(appModel.serverAddress)")

    // Try to fetch markers with more detailed logging
    print("📊 MarkersView attempting to fetch markers...")
    if isMultiTagMode && !selectedTagIds.isEmpty {
      // Initialize multiTagPages with page 1 for each tag
      multiTagPages = [:]
      for tagId in selectedTagIds {
        multiTagPages[tagId] = 1
      }
      // Fetch markers server-side for multi-tag selection
      await appModel.api.fetchMarkersByTags(
        tagIds: Array(selectedTagIds), page: 1, perPage: 25, appendResults: false)  // NEW multi-tag fetch
    } else if let tagId = selectedTagId {
      await appModel.api.fetchMarkersByTag(tagId: tagId, page: currentPage, appendResults: false)
    } else {
      await appModel.api.fetchMarkers(page: currentPage, appendResults: false)
    }
    print("📊 MarkersView markers fetch completed, received: \(appModel.api.markers.count)")

    await MainActor.run {
      allMarkers = appModel.api.markers
      updateDisplayedMarkers()
      extractAvailableTags()
      // Set initial pagination state
      hasMorePages = appModel.api.markers.count < appModel.api.totalMarkerCount
      isLoading = false
      print(
        "📊 MarkersView: Set allMarkers=\(allMarkers.count), displayedMarkers=\(displayedMarkers.count), total=\(appModel.api.totalMarkerCount), hasMore=\(hasMorePages)"
      )
    }
  }

  private func preloadNextPage() async {
    guard !isLoadingMore && hasMorePages else { return }

    print("Preloading next page of markers")
    let tempLoadingFlag = isLoadingMore
    isLoadingMore = true

    let nextPage = currentPage + 1
    let previousCount = appModel.api.markers.count

    do {
      if isMultiTagMode && !selectedTagIds.isEmpty {
        // Initialize multiTagPages if empty
        if multiTagPages.isEmpty {
          multiTagPages = [:]
          for tagId in selectedTagIds {
            multiTagPages[tagId] = 1
          }
        }
        // Fetch next page server-side for multi-tag selection not supported here, so fallback:
        await appModel.api.fetchMarkersByTags(
          tagIds: Array(selectedTagIds), page: nextPage, perPage: 25, appendResults: true)  // NEW multi-tag fetch
        // Update multiTagPages for all selected tags (set to nextPage)
        for tagId in selectedTagIds {
          multiTagPages[tagId] = nextPage
        }
      } else if let tagId = selectedTagId {
        await appModel.api.fetchMarkersByTag(tagId: tagId, page: nextPage, appendResults: true)
      } else {
        await appModel.api.fetchMarkers(page: nextPage, appendResults: true)
      }
    } catch {
      print("Error preloading next page: \(error)")
    }

    updateDisplayedMarkers()
    print("Preloaded \(displayedMarkers.count - previousCount) markers for smooth scrolling")

    // Only update current page if we successfully preloaded data
    if displayedMarkers.count > previousCount {
      currentPage = nextPage
      hasMorePages = true
    } else {
      hasMorePages = false
    }

    isLoadingMore = tempLoadingFlag
  }

  private func loadMoreMarkers() async {
    guard !isLoadingMore else { return }

    if isMultiTagMode && !selectedTagIds.isEmpty {
      await loadMoreMarkersForMultiTag()
      return
    }

    isLoadingMore = true
    currentPage += 1

    let previousCount = appModel.api.markers.count

    // NEW multi-tag server-side pagination fetch
    if isMultiTagMode && !selectedTagIds.isEmpty {
      await appModel.api.fetchMarkersByTags(
        tagIds: Array(selectedTagIds), page: currentPage, perPage: 25, appendResults: true)
    } else if let tagId = selectedTagId {
      await appModel.api.fetchMarkersByTag(tagId: tagId, page: currentPage, appendResults: true)
    } else {
      await appModel.api.fetchMarkers(page: currentPage, appendResults: true)
    }
    updateDisplayedMarkers()

    isLoadingMore = false
    // Check if there are more markers available based on total count
    hasMorePages = appModel.api.markers.count < appModel.api.totalMarkerCount
    print(
      "📊 Pagination check: loaded=\(appModel.api.markers.count), total=\(appModel.api.totalMarkerCount), hasMore=\(hasMorePages)"
    )
  }

  /// Load more markers for multi-tag selection by paging each tag individually
  private func loadMoreMarkersForMultiTag() async {
    guard !isLoadingMore else { return }
    isLoadingMore = true

    var anyNewMarkersLoaded = false
    var allNewMarkersSet = Set<SceneMarker>(allMarkers)

    // Ensure multiTagPages has entries for all selected tags
    for tagId in selectedTagIds where multiTagPages[tagId] == nil {
      multiTagPages[tagId] = 1
    }

    for tagId in selectedTagIds {
      // Increment page for this tag
      let nextPage = (multiTagPages[tagId] ?? 1) + 1
      multiTagPages[tagId] = nextPage

      do {
        await appModel.api.fetchMarkersByTag(tagId: tagId, page: nextPage, appendResults: true)
        let newMarkers = appModel.api.markers
        let beforeCount = allNewMarkersSet.count
        allNewMarkersSet.formUnion(newMarkers)
        if allNewMarkersSet.count > beforeCount {
          anyNewMarkersLoaded = true
        }
      } catch {
        print("Error loading more markers for tag \(tagId): \(error)")
      }
    }

    await MainActor.run {
      allMarkers = Array(allNewMarkersSet)
      updateDisplayedMarkers()
      // Update hasMorePages if any new markers loaded, else false
      hasMorePages = anyNewMarkersLoaded
      isLoadingMore = false
      print("📊 Multi-tag pagination: loaded more markers, hasMorePages=\(hasMorePages)")
    }
  }

  private func searchMarkers(query: String) async {
    do {
      await appModel.api.searchMarkers(query: query)
    } catch {
      print("Error searching markers: \(error)")
    }
    visibleMarkers.removeAll()
    selectedTagId = nil
    updateDisplayedMarkers()
  }

  /// Fetch markers filtered by multiple selected tags from the server
  /// This replaces the previous updateDisplayedMarkersForTags() usage for multi-tag selections
  /// Now fetches markers for each selected tag individually and combines them client-side for OR logic.
  private func fetchMarkersForMultiTagSelection() async {
    await MainActor.run {
      isLoading = true
      multiTagPages = [:]
      for tagId in selectedTagIds {
        multiTagPages[tagId] = 1
      }
    }
    do {
      if selectedTagIds.isEmpty {
        // If no tags selected, fetch all markers
        await appModel.api.fetchMarkers(page: 1, appendResults: false)
        await MainActor.run {
          allMarkers = appModel.api.markers
          updateDisplayedMarkers()
          extractAvailableTags()
          isLoading = false
          currentPage = 1
          hasMorePages = appModel.api.markers.count < appModel.api.totalMarkerCount
        }
      } else {
        var combinedMarkersSet = Set<SceneMarker>()
        var tempMarkersArray: [SceneMarker] = []

        // Fetch markers for each tag individually
        for tagId in selectedTagIds {
          await appModel.api.fetchMarkersByTag(tagId: tagId, page: 1, appendResults: false)
          tempMarkersArray = appModel.api.markers
          combinedMarkersSet.formUnion(tempMarkersArray)
        }

        await MainActor.run {
          allMarkers = Array(combinedMarkersSet)
          updateDisplayedMarkers()
          extractAvailableTags()
          isLoading = false
          currentPage = 1
          hasMorePages = allMarkers.count < appModel.api.totalMarkerCount
        }
      }
    } catch {
      print("❌ Error fetching markers for multi-tag selection: \(error)")
      await MainActor.run {
        isLoading = false
      }
    }
  }
}

struct MarkersView_Previews: PreviewProvider {
  static var previews: some View {
    MarkersView()
      .environmentObject(NavigationModel())
  }
}
