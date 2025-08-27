import RealityKit
import SwiftUI

struct MainVisionView: View {
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var navigationModel: NavigationModel
  @StateObject private var api = StashAPI()

  // Split out views to avoid the compiler's type checking timeout
  private var sidebarContent: some View {
    List {
      // App title with actual logo from file system
      HStack(spacing: 8) {
        // The actual app logo from the specified path
        Image("image")
          .resizable()
          .scaledToFit()
          .frame(width: 36, height: 36)
          .clipShape(RoundedRectangle(cornerRadius: 8))

        Text("Stash")
          .font(.title3.bold())
          .foregroundColor(.white)
      }
      .listRowBackground(Color.clear)
      .padding(.bottom, 12)

      // VPN Status Indicator
      HStack {
        Spacer()
        VPNStatusIndicator()
        Spacer()
      }
      .listRowBackground(Color.clear)
      .padding(.bottom, 16)

      // Navigation links
      ForEach(NavigationItem.allCases) { item in
        Button(action: {
          navigationModel.navigateTo(item)
        }) {
          Label(
            title: { Text(item.rawValue) },
            icon: { Image(systemName: item.icon) }
          )
          .foregroundColor(navigationModel.selectedTab == item ? .white : .white.opacity(0.7))
          .font(navigationModel.selectedTab == item ? .body.weight(.medium) : .body)
        }
        .buttonStyle(.plain)
        .listRowBackground(
          navigationModel.selectedTab == item ? Color.white.opacity(0.15) : Color.clear
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.black.opacity(0.001))  // Nearly transparent background
    .toolbar(.hidden, for: .navigationBar)
  }

  private var detailContent: some View {
    ZStack {
      // Background with uniform rounded corners
      RoundedRectangle(cornerRadius: 30)
        .fill(Color.black.opacity(0.05))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 0)
        .overlay(
          RoundedRectangle(cornerRadius: 30)
            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )

      // Main content
      contentViewForTab
        .padding(2)  // Slight inset to preserve rounded corners
    }
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
        case .vr:
          XBVRLibraryView()
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
    // Add video player overlay
    .overlay {
      if appModel.isShowingPlayer, let scene = appModel.selectedScene {
        VideoPlayerView(scene: scene)
          .environmentObject(navigationModel)
          .transition(.opacity)
          .onDisappear {
            print("🎬 Video player disappeared")
            appModel.isShowingPlayer = false
            appModel.selectedScene = nil
          }
          .onAppear {
            // Listen for dismiss notification
            NotificationCenter.default.addObserver(
              forName: .init("DismissVideoPlayer"),
              object: nil,
              queue: .main
            ) { _ in
              print("🎬 Received dismiss notification")
              appModel.isShowingPlayer = false
              appModel.selectedScene = nil
            }

            // Listen for auto-skip request from player manager
            NotificationCenter.default.addObserver(
              forName: .init("RequestShuffleNextScene"),
              object: nil,
              queue: .main
            ) { _ in
              print("🎬 Auto-skip requested — shuffling to next scene")
              appModel.isShowingPlayer = false
              // Defer shuffling slightly to let cleanup settle
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appModel.isShowingPlayer = true
              }
            }
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
  case vr = "VR"
  case settings = "Settings"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .media: return "play.circle.fill"
    case .performers: return "person.2.fill"
    case .markers: return "bookmark.circle.fill"
    case .tags: return "tag.circle.fill"
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
