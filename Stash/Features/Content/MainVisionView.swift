import RealityKit
import SwiftUI

struct MainVisionView: View {
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var navigationModel: NavigationModel
  @StateObject private var api = StashAPI()
  @State private var dismissObserver: NSObjectProtocol?
  @State private var shuffleObserver: NSObjectProtocol?

  // Split out views to avoid the compiler's type checking timeout
  private var sidebarContent: some View {
    List {
      Section {
        // App title with actual logo from file system
        HStack(spacing: 12) {
          Image("image")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .hoverEffect()

          Text("Stash")
            .font(.title2.bold())
            .foregroundStyle(.primary)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))

        // VPN Status Indicator with depth alignment for better spatial positioning
        VPNStatusIndicator()
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
      }
      .listSectionSeparator(.hidden)

      Section("Library") {
        ForEach(NavigationItem.allCases) { item in
          Button(action: {
            navigationModel.navigateTo(item)
          }) {
            Label(item.rawValue, systemImage: item.icon)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .hoverEffect(.highlight)
          .listRowBackground(
            navigationModel.selectedTab == item
              ? Color.white.opacity(0.1)
              : Color.clear
          )
        }
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.visible)
  }

  private var detailContent: some View {
    contentViewForTab
      .background(.ultraThinMaterial)
      .glassBackgroundEffect()
      .clipShape(RoundedRectangle(cornerRadius: 30))
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // Break out the content view as a computed property to reduce complexity
  @ViewBuilder
  private var contentViewForTab: some View {
    NavigationStack(path: $navigationModel.navigationPath) {
      Group {
        switch navigationModel.selectedTab {
        case .media:
          MediaLibraryView()
        case .performers:
          PerformersView()
            .environmentObject(api)
        case .markers:
          MarkersView()
        case .tags:
          TagSearchView()
        case .history:
          HistoryView()
        case .vr:
          VRLibraryView()
        case .settings:
          SettingsView()
            .environmentObject(api)
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .performer(let performer):
          PerformerScenesView(performer: performer)
            .environmentObject(api)
        case .marker(let marker):
          // Add a marker detail view if needed
          Text("Marker Detail: \(marker.title)")
        case .scene(let scene):
          // Add a scene detail view if needed
          Text("Scene Detail: \(scene.title)")
        case .tag(let tag):
          TaggedScenesView(tag: tag)
            .environmentObject(appModel)
        case .tagMarkers(let tag):
          TaggedMarkersView(tag: tag)
            .environmentObject(appModel)
        }
      }
    }
  }

  var body: some View {
    // Using the native NavigationSplitView to create a proper visionOS sidebar
    NavigationSplitView {
      // Break out the sidebar to a separate variable to simplify type checking
      sidebarContent
    } detail: {
      // Break out the detail view to a separate variable to simplify type checking
      detailContent
    }
    .navigationSplitViewStyle(.prominentDetail)
    .preferredColorScheme(.dark)
    // visionOS 2.6: Use fullScreenCover for better presentation in volumes
    .fullScreenCover(isPresented: $appModel.isShowingPlayer) {
      if let scene = appModel.selectedScene {
        VideoPlayerView(scene: scene)
          .environmentObject(navigationModel)
          .environmentObject(appModel)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
          .onAppear {
            // Store observer tokens to clean them up later
            dismissObserver = NotificationCenter.default.addObserver(
              forName: .init("DismissVideoPlayer"),
              object: nil,
              queue: .main
            ) { _ in
              print("🎬 Received dismiss notification")
              appModel.isShowingPlayer = false
              appModel.selectedScene = nil
            }

            shuffleObserver = NotificationCenter.default.addObserver(
              forName: .init("RequestShuffleNextScene"),
              object: nil,
              queue: .main
            ) { _ in
              print("🎬 Auto-skip requested — shuffling to next scene")
              appModel.isShowingPlayer = false
              Task {
                try? await Task.sleep(for: .seconds(0.2))
                appModel.isShowingPlayer = true
              }
            }
          }
          .onDisappear {
            print("🎬 Video player disappeared")

            // Remove notification observers to prevent memory leaks
            if let observer = dismissObserver {
              NotificationCenter.default.removeObserver(observer)
              dismissObserver = nil
            }
            if let observer = shuffleObserver {
              NotificationCenter.default.removeObserver(observer)
              shuffleObserver = nil
            }

            appModel.isShowingPlayer = false
            appModel.selectedScene = nil
          }
      }
    }
  }
}

enum NavigationItem: String, CaseIterable, Identifiable {
  case media = "Media"
  case performers = "Performers"
  case markers = "Markers"
  case tags = "Tags"
  case history = "History"
  case vr = "VR"
  case settings = "Settings"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .media: return "play.circle.fill"
    case .performers: return "person.2.fill"
    case .markers: return "bookmark.circle.fill"
    case .tags: return "tag.circle.fill"
    case .history: return "clock.arrow.circlepath"
    case .vr: return "visionpro.fill"
    case .settings: return "gear.circle.fill"
    }
  }
}

struct MainVisionView_Previews: PreviewProvider {
  static var previews: some View {
    MainVisionView()

      .environmentObject(NavigationModel())
  }
}
