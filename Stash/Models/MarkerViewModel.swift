import Combine
import Foundation
import SwiftUI

/// The sorting options for markers
enum MarkerSortOption: String, CaseIterable, Identifiable {
  case timestamp = "timestamp"
  case title = "title"
  case createdAtDesc = "created_at_desc"
  case createdAtAsc = "created_at_asc"
  case sceneTitleAsc = "scene_title_asc"
  case sceneTitleDesc = "scene_title_desc"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .timestamp: return "Time"
    case .title: return "Title"
    case .createdAtDesc: return "Newest First"
    case .createdAtAsc: return "Oldest First"
    case .sceneTitleAsc: return "Scene (A-Z)"
    case .sceneTitleDesc: return "Scene (Z-A)"
    }
  }
}

/// ViewModel for managing marker data and operations
class MarkerViewModel: ObservableObject {
  // MARK: - Published Properties
  @Published var markers: [SceneMarker] = []
  @Published var filteredMarkers: [SceneMarker] = []
  @Published var isLoading: Bool = false
  @Published var isLoadingMore: Bool = false
  @Published var hasMorePages: Bool = true
  @Published var error: String?
  @Published var availableTags: [StashScene.Tag] = []

  // MARK: - Private Properties
  private var currentPage: Int = 1
  private var visibleMarkers: Set<String> = []
  private var currentSortOption: MarkerSortOption = .timestamp
  private var currentTagFilter: String?
  private var cancellables = Set<AnyCancellable>()
  private var sceneId: String?
  private var performerId: String?

  // MARK: - Methods for loading markers

  /// Load markers for a specific scene
  /// - Parameters:
  ///   - scene: The scene to load markers for
  ///   - api: The StashAPI instance to use
  func loadMarkers(for scene: StashScene, api: StashAPI) async {
    await MainActor.run {
      self.isLoading = true
      self.error = nil
      self.sceneId = scene.id
      self.performerId = nil
      self.currentPage = 1
      self.hasMorePages = true
    }

    // Since fetchSceneMarkers doesn't exist, we'll use a direct GraphQL query
    do {
      let query = """
        {
            "operationName": "FindSceneMarkers",
            "variables": {
                "filter": {
                    "q": "",
                    "page": 1,
                    "per_page": 100,
                    "sort": "timestamp",
                    "direction": "ASC"
                }, 
                "scene_marker_filter": {
                    "scene_ids": {
                        "value": ["\(scene.id)"],
                        "modifier": "INCLUDES"
                    }
                }
            },
            "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count markers { id title seconds stream scene { id name date created_at title studio { id name } performers { id name } files { height width duration } galleries { id } } preview tags { id name } primary_tag { id name } screenshot } } }"
        }
        """

      let data = try await api.executeGraphQLQuery(query)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)
      let loadedMarkers = response.data.findSceneMarkers.markers

      // Extract all tags from markers for filtering
      let extractedTags = await MainActor.run { () -> [StashScene.Tag] in
        var tags = Set<StashScene.Tag>()

        for marker in loadedMarkers {
          // Add primary tag if available
          if let primaryTag = marker.primary_tag {
            let stashTag = StashScene.Tag(
              id: primaryTag.id, name: primaryTag.name, scene_count: 0, image_count: 0,
              scene_marker_count: 0)
            tags.insert(stashTag)
          }

          // Add other tags
          if let markerTags = marker.tags {
            for tag in markerTags {
              let stashTag = StashScene.Tag(
                id: tag.id, name: tag.name, scene_count: 0, image_count: 0, scene_marker_count: 0)
              tags.insert(stashTag)
            }
          }
        }

        return Array(tags).sorted { $0.name < $1.name }
      }

      await MainActor.run {
        self.markers = loadedMarkers
        self.filteredMarkers = loadedMarkers
        self.availableTags = extractedTags
        self.isLoading = false
        self.hasMorePages = loadedMarkers.count >= 100  // Assuming 100 per page
      }
    } catch {
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoading = false
      }
      print("Error loading markers: \(error)")
    }
  }

  /// Load markers for a specific performer
  /// - Parameters:
  ///   - performer: The performer to load markers for
  ///   - api: The StashAPI instance to use
  func loadMarkers(for performer: StashScene.Performer, api: StashAPI) async {
    print("🧩 DEBUG MARKERVM: Loading markers for performer \(performer.name) (ID: \(performer.id))")

    await MainActor.run {
      self.isLoading = true
      self.error = nil
      self.performerId = performer.id
      self.sceneId = nil
      self.currentPage = 1
      self.hasMorePages = true
    }

    do {
      // Fetch performer markers using shared API implementation
      let loadedMarkers = try await api.fetchPerformerMarkers(performerId: performer.id, page: 1)

      // Debug count
      print(
        "🧩 DEBUG MARKERVM: Received \(loadedMarkers.count) markers for performer \(performer.name)")

      // Extract all tags from markers for filtering
      var tags = Set<StashScene.Tag>()
      for marker in loadedMarkers {
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

      await MainActor.run {
        self.markers = loadedMarkers
        self.filteredMarkers = loadedMarkers
        self.availableTags = Array(tags).sorted { $0.name < $1.name }
        self.isLoading = false
        self.hasMorePages = loadedMarkers.count >= 40
        print("🧩 DEBUG MARKERVM: Updated state with \(self.markers.count) markers")
      }
    } catch {
      print("❌ DEBUG MARKERVM ERROR: Error loading markers for performer: \(error)")
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoading = false
      }
    }
  }

  /// Load all markers
  /// - Parameter api: The StashAPI instance to use
  func loadAllMarkers(api: StashAPI) async {
    print("📊 MarkerViewModel: Starting to load all markers")
    await MainActor.run {
      self.isLoading = true
      self.error = nil
      self.sceneId = nil
      self.performerId = nil
      self.currentPage = 1
      self.hasMorePages = true
    }

    // Use the existing fetchMarkers method from StashAPI
    await api.fetchMarkers(page: 1, appendResults: false)

    // Get the markers from the API
    let loadedMarkers = await api.markers
    print("📊 MarkerViewModel: Received \(loadedMarkers.count) markers from API")

    await MainActor.run {
      // Extract all tags from markers for filtering
      var tags = Set<StashScene.Tag>()
      for marker in loadedMarkers {
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

      self.markers = loadedMarkers
      self.filteredMarkers = loadedMarkers
      self.availableTags = Array(tags).sorted { $0.name < $1.name }
      self.isLoading = false
      self.hasMorePages = loadedMarkers.count >= 40
      print(
        "✅ MarkerViewModel: Updated state with \(self.markers.count) markers and \(self.availableTags.count) available tags"
      )
    }
  }

  /// Load more markers for pagination
  func loadMoreMarkers() async {
    guard !isLoadingMore, hasMorePages else { return }

    await MainActor.run {
      self.isLoadingMore = true
      self.currentPage += 1
    }

    if let performerId = performerId {
      // Using performer markers
      await loadMorePerformerMarkers(performerId: performerId)
    } else if let sceneId = sceneId {
      // Using scene markers
      await loadMoreSceneMarkers(sceneId: sceneId)
    } else {
      // Loading all markers
      await loadMoreAllMarkers()
    }
  }

  // MARK: - Helper methods for loading more markers

  private func loadMorePerformerMarkers(performerId: String) async {
    do {
      let api = await StashAPI()

      // Fetch next page of performer markers
      let newMarkers = try await api.fetchPerformerMarkers(
        performerId: performerId, page: currentPage)

      await MainActor.run {
        self.hasMorePages = !newMarkers.isEmpty

        // Filter out duplicates
        let newUnique = newMarkers.filter { nm in
          !self.markers.contains { $0.id == nm.id }
        }
        print(
          "📊 PAGINATION: Page \(currentPage) loaded \(newMarkers.count) markers, \(newUnique.count) new"
        )

        self.markers.append(contentsOf: newUnique)
        if let tagId = self.currentTagFilter {
          self.filterMarkersByTag(tagId: tagId)
        } else {
          self.filteredMarkers = self.markers
        }
        self.sortMarkers(by: self.currentSortOption)
        self.isLoadingMore = false
      }
    } catch {
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoadingMore = false
        self.hasMorePages = false
      }
      print("❌ ERROR loading more performer markers: \(error)")
    }
  }

  private func loadMoreSceneMarkers(sceneId: String) async {
    // Direct GraphQL query for pagination with scene id
    do {
      let api = await StashAPI()

      let query = """
        {
            "operationName": "FindSceneMarkers",
            "variables": {
                "filter": {
                    "q": "",
                    "page": \(currentPage),
                    "per_page": 40,
                    "sort": "timestamp",
                    "direction": "ASC"
                },
                "scene_marker_filter": {
                    "scene_ids": {
                        "value": ["\(sceneId)"],
                        "modifier": "INCLUDES"
                    }
                }
            },
            "query": "query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) { findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) { count markers { id title seconds stream scene { id name date created_at title studio { id name } performers { id name } files { height width duration } galleries { id } } preview tags { id name } primary_tag { id name } screenshot } } }"
        }
        """

      let data = try await api.executeGraphQLQuery(query)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)
      let newMarkers = response.data.findSceneMarkers.markers

      await MainActor.run {
        self.hasMorePages = !newMarkers.isEmpty

        // Filter out duplicates
        let newUniqueMarkers = newMarkers.filter { newMarker in
          !self.markers.contains { $0.id == newMarker.id }
        }

        self.markers.append(contentsOf: newUniqueMarkers)

        // Apply filtering if needed
        if let tagId = self.currentTagFilter {
          self.filterMarkersByTag(tagId: tagId)
        } else {
          self.filteredMarkers = self.markers
        }

        self.sortMarkers(by: self.currentSortOption)
        self.isLoadingMore = false
      }
    } catch {
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoadingMore = false
        self.hasMorePages = false
      }
    }
  }

  private func loadMoreAllMarkers() async {
    // Direct GraphQL query for pagination of all markers
    do {
      let api = await StashAPI()

      let query = """
        {
            "operationName": "FindSceneMarkers",
            "variables": {
                "filter": {
                    "q": "",
                    "page": \(currentPage),
                    "per_page": 40,
                    "sort": "created_at",
                    "direction": "DESC"
                }
            },
            "query": "query FindSceneMarkers($filter: FindFilterType) { findSceneMarkers(filter: $filter) { count markers { id title seconds stream scene { id name date created_at title studio { id name } performers { id name } files { height width duration } galleries { id } } preview tags { id name } primary_tag { id name } screenshot } } }"
        }
        """

      let data = try await api.executeGraphQLQuery(query)

      struct MarkersResponseData: Decodable {
        let data: MarkerData

        struct MarkerData: Decodable {
          let findSceneMarkers: MarkersPayload

          struct MarkersPayload: Decodable {
            let count: Int
            let markers: [SceneMarker]
          }
        }
      }

      let response = try JSONDecoder().decode(MarkersResponseData.self, from: data)
      let newMarkers = response.data.findSceneMarkers.markers

      await MainActor.run {
        self.hasMorePages = !newMarkers.isEmpty

        // Filter out duplicates
        let newUniqueMarkers = newMarkers.filter { newMarker in
          !self.markers.contains { $0.id == newMarker.id }
        }

        self.markers.append(contentsOf: newUniqueMarkers)

        // Apply filtering if needed
        if let tagId = self.currentTagFilter {
          self.filterMarkersByTag(tagId: tagId)
        } else {
          self.filteredMarkers = self.markers
        }

        self.sortMarkers(by: self.currentSortOption)
        self.isLoadingMore = false
      }
    } catch {
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoadingMore = false
        self.hasMorePages = false
      }
    }
  }

  // MARK: - Filtering & Sorting

  /// Reset the tag filter to show all markers
  func resetTagFilter() {
    self.currentTagFilter = nil
    self.filteredMarkers = self.markers
    self.sortMarkers(by: self.currentSortOption)
  }

  /// Filter markers by a specific tag ID
  /// - Parameter tagId: The tag ID to filter by
  func filterMarkersByTag(tagId: String) {
    self.currentTagFilter = tagId

    self.filteredMarkers = self.markers.filter { marker in
      // Check primary tag if available
      if let primaryTag = marker.primary_tag {
        if primaryTag.id == tagId {
          return true
        }
      }

      // Check other tags
      if let tags = marker.tags {
        return tags.contains { $0.id == tagId }
      }

      return false
    }

    self.sortMarkers(by: self.currentSortOption)
  }

  /// Sort markers by the specified option
  /// - Parameter option: The sort option to use
  func sortMarkers(by option: MarkerSortOption) {
    self.currentSortOption = option

    switch option {
    case .timestamp:
      self.filteredMarkers.sort { marker1, marker2 in
        return marker1.seconds < marker2.seconds
      }
    case .title:
      self.filteredMarkers.sort { marker1, marker2 in
        return marker1.title.localizedCaseInsensitiveCompare(marker2.title) == .orderedAscending
      }
    case .createdAtDesc:
      self.filteredMarkers.sort { marker1, marker2 in
        // Since MarkerScene doesn't have created_at, use ID as a fallback
        // IDs are often sequential and can approximate creation order
        return marker1.id > marker2.id
      }
    case .createdAtAsc:
      self.filteredMarkers.sort { marker1, marker2 in
        // Since MarkerScene doesn't have created_at, use ID as a fallback
        return marker1.id < marker2.id
      }
    case .sceneTitleAsc:
      self.filteredMarkers.sort { marker1, marker2 in
        let title1 = marker1.scene?.title ?? ""
        let title2 = marker2.scene?.title ?? ""
        return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
      }
    case .sceneTitleDesc:
      self.filteredMarkers.sort { marker1, marker2 in
        let title1 = marker1.scene?.title ?? ""
        let title2 = marker2.scene?.title ?? ""
        return title1.localizedCaseInsensitiveCompare(title2) == .orderedDescending
      }
    }
  }
}
