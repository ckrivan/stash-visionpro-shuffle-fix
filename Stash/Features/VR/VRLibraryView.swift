import SwiftUI

struct VRLibraryView: View {
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var navigationModel: NavigationModel
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  @State private var scenes: [StashScene] = []
  @State private var isLoading = false
  @State private var error: Error?
  @State private var currentPage = 1
  @State private var hasMorePages = true
  @State private var isImmersiveActive = false
  @State private var selectedSceneID: String?
  // Fallback sheet for non-visionOS platforms
  @State private var showVRSheet = false
  @State private var debugMessage: String = ""
  @State private var vrTagID: String?
  @State private var isOpeningMoonPlayer = false

  var body: some View {
    NavigationStack {
      ScrollView {
        // Compute columns based on screen size with consistent spacing
        let columns = [
          GridItem(.adaptive(minimum: 340, maximum: 400), spacing: 20)
        ]

        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(scenes) { scene in
            VRSceneCard(scene: scene, onPlay: handleSceneSelection)
              .frame(maxWidth: .infinity)
              .frame(height: 300)  // Fixed height for consistency
              .onTapGesture { handleSceneSelection(scene) }
          }
          if hasMorePages {
            ProgressView()
              .frame(height: 50)
              .onAppear { loadMoreScenes() }
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .navigationTitle("VR Library")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          NavigationLink(destination: SettingsView()) {
            Label("Settings", systemImage: "gearshape")
          }
        }
      }
      .overlay {
        if isLoading && scenes.isEmpty {
          ProgressView()
        }
      }
      .overlay(alignment: .bottom) {
        if let error = error {
          Text(error.localizedDescription)
            .foregroundColor(.white)
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(8)
            .padding()
        }
      }
      .overlay(alignment: .bottom) {
        if !debugMessage.isEmpty {
          Text(debugMessage)
            .font(.caption)
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }
      }
      .onAppear {
        if scenes.isEmpty {
          Task { await findVRTagID() }
        }
      }
    }
    // Fallback 2D video sheet for non-visionOS platforms
    .sheet(isPresented: $showVRSheet) {
      if let id = selectedSceneID,
        let scene = scenes.first(where: { $0.id == id }) {
        VRVideoView(scene: scene)
          .environmentObject(appModel)
      }
    }
  }

  private func findVRTagID() async {
    isLoading = true
    error = nil
    debugMessage = "Finding VR tag ID..."

    do {
      let api = StashAPI()
      let tags = try await api.searchTags(query: "vr")

      if let vrTag = tags.first(where: { $0.name.lowercased() == "vr" }) {
        vrTagID = vrTag.id
        debugMessage = "Found VR tag with ID: \(vrTag.id)"
        await loadScenes()
      } else {
        // Try to find tags containing VR, 180, or 360
        let vrRelatedTags = tags.filter {
          $0.name.lowercased().contains("vr") || $0.name.lowercased().contains("180")
            || $0.name.lowercased().contains("360")
        }

        if let firstVRTag = vrRelatedTags.first {
          vrTagID = firstVRTag.id
          debugMessage = "Found related VR tag: \(firstVRTag.name) with ID: \(firstVRTag.id)"
          await loadScenes()
        } else {
          // Try a broader search
          let moreTags = try await api.searchTags(query: "180")
          if let tag180 = moreTags.first {
            vrTagID = tag180.id
            debugMessage = "Found 180 tag with ID: \(tag180.id)"
            await loadScenes()
          } else {
            error = NSError(
              domain: "VRLibrary", code: 404,
              userInfo: [NSLocalizedDescriptionKey: "No VR tag found in the database"])
            debugMessage =
              "No VR tags found in database. Please create a tag named 'vr' for VR content."
            isLoading = false
          }
        }
      }
    } catch {
      self.error = error
      debugMessage = "Error finding VR tag: \(error.localizedDescription)"
      isLoading = false
    }
  }

  private func loadScenes() async {
    // Ensure we have a VR tag ID
    guard let tagID = vrTagID else {
      debugMessage = "No VR tag ID available"
      return
    }

    isLoading = true
    error = nil
    debugMessage = "Loading VR scenes with tag ID: \(tagID)"

    do {
      let api = StashAPI()

      // Create a direct GraphQL query instead of using SceneFilterType
      let graphQLQuery = """
        {
          findScenes(
            filter: {
              page: \(currentPage),
              per_page: 20
            },
            scene_filter: {
              tags: {
                value: ["\(tagID)"],
                modifier: INCLUDES
              }
            }
          ) {
            count
            scenes {
              id
              title
              details
              date
              rating100
              o_counter
              paths {
                screenshot
                stream
                preview
              }
              tags {
                id
                name
              }
              performers {
                id
                name
                image_path
              }
              studio {
                id
                name
              }
              files {
                width
                height
                video_codec
              }
            }
          }
        }
        """

      // Use the public executeGraphQLQuery method
      let data = try await api.executeGraphQLQuery(graphQLQuery)

      // Define a local response structure
      struct FindScenesResponse: Decodable {
        struct Data: Decodable {
          struct FindScenes: Decodable {
            let count: Int
            let scenes: [StashScene]
          }
          let findScenes: FindScenes
        }
        let data: Data
      }

      // Decode the response
      let decoder = JSONDecoder()
      let response = try decoder.decode(FindScenesResponse.self, from: data)

      scenes = response.data.findScenes.scenes
      hasMorePages = response.data.findScenes.scenes.count >= 20
      debugMessage =
        "Loaded \(response.data.findScenes.scenes.count) VR scenes (total: \(response.data.findScenes.count))"
      isLoading = false
    } catch {
      self.error = error
      debugMessage = "Error loading scenes: \(error.localizedDescription)"
      isLoading = false
    }
  }

  private func loadMoreScenes() {
    Task {
      await loadMoreScenesAsync()
    }
  }

  private func loadMoreScenesAsync() async {
    guard !isLoading && hasMorePages else { return }
    guard let tagID = vrTagID else {
      debugMessage = "No VR tag ID available for loading more scenes"
      return
    }

    isLoading = true
    debugMessage = "Loading more VR scenes with tag ID: \(tagID), page: \(currentPage + 1)"

    do {
      let api = StashAPI()

      // Create a direct GraphQL query for the next page
      let nextPage = currentPage + 1
      let graphQLQuery = """
        {
          findScenes(
            filter: {
              page: \(nextPage),
              per_page: 20
            },
            scene_filter: {
              tags: {
                value: ["\(tagID)"],
                modifier: INCLUDES
              }
            }
          ) {
            count
            scenes {
              id
              title
              details
              date
              rating100
              o_counter
              paths {
                screenshot
                stream
                preview
              }
              tags {
                id
                name
              }
              performers {
                id
                name
                image_path
              }
              studio {
                id
                name
              }
              files {
                width
                height
                video_codec
              }
            }
          }
        }
        """

      // Use the public executeGraphQLQuery method
      let data = try await api.executeGraphQLQuery(graphQLQuery)

      // Define a local response structure
      struct FindScenesResponse: Decodable {
        struct Data: Decodable {
          struct FindScenes: Decodable {
            let count: Int
            let scenes: [StashScene]
          }
          let findScenes: FindScenes
        }
        let data: Data
      }

      // Decode the response
      let decoder = JSONDecoder()
      let response = try decoder.decode(FindScenesResponse.self, from: data)

      scenes.append(contentsOf: response.data.findScenes.scenes)
      currentPage = nextPage
      hasMorePages = response.data.findScenes.scenes.count >= 20
      debugMessage =
        "Loaded \(response.data.findScenes.scenes.count) additional VR scenes (page \(nextPage))"
      isLoading = false
    } catch {
      self.error = error
      debugMessage = "Error loading more scenes: \(error.localizedDescription)"
      isLoading = false
    }
  }

  private func handleSceneSelection(_ scene: StashScene) {
    print("🎬 Selected VR scene: \(scene.id)")
    debugMessage = "Selected: \(scene.title)"

    // Set the current scene in the app model
    appModel.currentScene = scene
    selectedSceneID = scene.id

    // Platform-specific handling: use immersive on visionOS, sheet fallback elsewhere
    #if os(visionOS)
      Task {
        do {
          debugMessage = "Opening immersive video scene..."
          // Open the pre-registered immersive space defined in App
          // First dismiss any existing immersive space
          try? await dismissImmersiveSpace()

          // Wait a moment to ensure clean transition
          try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

          // Open new immersive space
          try await openImmersiveSpace(id: "ImmersiveVideoSpace")
          debugMessage = "Immersive space opened"
          isImmersiveActive = true
          print("🎬 Opened immersive space with scene ID: \(scene.id)")
        } catch {
          debugMessage = "Failed to open immersive space: \(error.localizedDescription)"
          print("❌ Failed to open immersive space: \(error)")
        }
      }
      isImmersiveActive = true
    #else
      // Fallback to 2D video sheet on non-visionOS
      showVRSheet = true
    #endif
  }
}

// Unified scene card styling to match SceneRow and MarkerRow
struct VRSceneCard: View {
  let scene: StashScene
  let onPlay: (StashScene) -> Void
  @StateObject private var api = StashAPI()
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Thumbnail image with consistent dimensions
      ZStack(alignment: .topTrailing) {
        // Background for thumbnail with consistent aspect ratio
        Rectangle()
          .fill(.black.opacity(0.3))
          .aspectRatio(16 / 9, contentMode: .fit)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: 12))

        // Actual thumbnail image
        if let screenshotString = scene.paths.screenshot,
          let url = URL(string: screenshotString) {
          AsyncImage(url: url) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
          } placeholder: {
            ProgressView()
          }
          .aspectRatio(16 / 9, contentMode: .fit)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Standard play button
        Button {
          onPlay(scene)
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "play.fill")
            Text("VR Play")
          }
          .font(.system(size: 14, weight: .medium))
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(.blue.opacity(0.8))
          .foregroundColor(.white)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
        }
        .padding(12)
        .buttonStyle(.plain)
      }

      // Details section
      VStack(alignment: .leading, spacing: 10) {
        // Title
        Text(scene.title ?? "Untitled")
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.top, 12)

        // Performers
        if let performers = scene.performers, !performers.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(performers) { performer in
                Text(performer.name)
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.purple.opacity(0.2))
                  .clipShape(Capsule())
              }
            }
            .padding(.horizontal, 1)  // Reduces chance of clipping
          }
          .scrollClipDisabled()
        }

        // Tags - limited to showing only VR-related tags
        if let tags = scene.tags, !tags.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              // Show VR format tags first (if any)
              let vrTags = tags.filter { tag in
                let name = tag.name.lowercased()
                return name.contains("vr") || name.contains("180") || name.contains("360")
                  || name.contains("sbs") || name.contains("tb") || name.contains("side-by-side")
                  || name.contains("over-under")
              }

              // Show limited number of tags if there are too many
              let tagsToShow = vrTags.isEmpty ? Array(tags.prefix(3)) : vrTags

              ForEach(tagsToShow) { tag in
                Text(tag.name)
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.secondary.opacity(0.2))
                  .clipShape(Capsule())
              }

              // Add a "+X more" tag if there are more tags than we're showing
              if tags.count > 3 && vrTags.isEmpty {
                Text("+\(tags.count - 3) more")
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.tertiary.opacity(0.2))
                  .clipShape(Capsule())
              }
            }
            .padding(.horizontal, 1)  // Reduces chance of clipping
          }
          .scrollClipDisabled()
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .hoverEffect(.lift)
  }
}

struct VRLibraryView_Previews: PreviewProvider {
  static var previews: some View {
    VRLibraryView()
      
      .environmentObject(NavigationModel())
  }
}
