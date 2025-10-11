import SwiftUI

struct PerformerWindow: View {
  let performer: StashScene.Performer
  @StateObject private var api = StashAPI()
  @StateObject private var navigationModel = NavigationModel()
  @State private var selectedTab = 0
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var markerCount: Int = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Performer header
        PerformerHeaderView(performer: performer)

        // Tab picker
        Picker("View", selection: $selectedTab) {
          Text("Scenes").tag(0)
          Text("Markers").tag(1)
        }
        .pickerStyle(.segmented)
        .padding()

        TabView(selection: $selectedTab) {
          // Scenes Tab
          scenesContent
            .tag(0)

          // Markers Tab
          markersContent
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
      }
      .navigationTitle(performer.name)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismissWindow(id: WindowType.performer.rawValue)
          }
        }
      }
    }
    .task {
      // Load initial content based on selected tab
      if selectedTab == 0 {
        await loadScenes()
      } else {
        await loadMarkers()
      }
    }
    .onChange(of: selectedTab) { _ in
      Task {
        if selectedTab == 0 {
          await loadScenes()
        } else {
          await loadMarkers()
        }
      }
    }
  }

  private var scenesContent: some View {
    ScrollView {
      if api.scenes.isEmpty {
        Text("No scenes found")
          .foregroundColor(.secondary)
          .padding()
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
          ForEach(api.scenes) { scene in
            SceneRow(scene: scene, allScenes: api.scenes)
          }
        }
        .padding()
      }
    }
  }

  private var markersContent: some View {
    ScrollView {
      if api.markers.isEmpty {
        Text("No markers found")
          .foregroundColor(.secondary)
          .padding()
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
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
        .padding()
      }
    }
  }

  private func loadScenes() async {
    try? await api.fetchScenes()
  }

  private func loadMarkers() async {
    try? await api.fetchMarkers()
  }
}
