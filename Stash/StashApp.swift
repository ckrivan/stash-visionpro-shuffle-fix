//
//  StashApp.swift
//  Stash
//
//  Created by Charles Krivan on 12/14/24.
//

import RealityKit
import SwiftUI
import UIKit

// Create a class-based notification handler to avoid struct mutability issues
class AppNotificationHandler {
  static let shared = AppNotificationHandler()

  func setupRandomSceneObserver(appModel: AppModel) {
    NotificationCenter.default.addObserver(
      forName: Notification.Name("OpenRandomScene"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      if let userInfo = notification.userInfo,
        let sceneID = userInfo["sceneID"] as? String,
        let startTime = userInfo["startTime"] as? Double
      {
        Task {
          // Handle opening random scene
          let api = StashAPI()
          do {
            if let scene = try await api.fetchScene(byID: sceneID) {
              await MainActor.run {
                appModel.videoStartTime = startTime
                appModel.openScene(scene, startTime: startTime)
              }
            }
          } catch {
            print("Error loading random scene: \(error)")
          }
        }
      }
    }
  }
}

@MainActor
class XBVRPlayerState: ObservableObject {
  @Published var currentVideo: XBVRVideo?
}

@main
struct StashApp: App {
  @StateObject private var appModel = AppModel()
  @StateObject private var navigationModel = NavigationModel()
  @StateObject private var xbvrPlayerState = XBVRPlayerState()

  init() {
    // Configure URLCache for better image/video caching performance
    // 50MB memory cache, 500MB disk cache (up from default 5MB/20MB)
    let memoryCapacity = 50 * 1024 * 1024  // 50MB
    let diskCapacity = 500 * 1024 * 1024  // 500MB
    let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
    URLCache.shared = urlCache
    print(
      "📦 URLCache configured: \(memoryCapacity / 1024 / 1024)MB memory, \(diskCapacity / 1024 / 1024)MB disk"
    )
  }

  var body: some SwiftUI.Scene {
    WindowGroup {
      ContentView()
        .environmentObject(appModel)
        .environmentObject(navigationModel)
        .environmentObject(xbvrPlayerState)
        .onChange(of: UIApplication.shared.applicationState) { _, newState in
          if newState != .active {
            // App is entering background, cleanup any resources
            appModel.cleanupResources()
          }
        }
        .onOpenURL { url in
          // Handle deep links if needed
          print("Received deep link: \(url)")
        }
    }
    // Start larger and let user resize as needed
    .windowResizability(.automatic)
    .defaultSize(width: 1400, height: 900)

    // Register the immersive space for VR video playback
    ImmersiveSpace(id: "ImmersiveVideoSpace") {
      ImmersiveVideoScene()
        .environmentObject(appModel)
        .environmentObject(navigationModel)
        .persistentSystemOverlays(.hidden)  // Hide system UI overlays
    }
    .immersionStyle(selection: .constant(.full), in: .full)
    .upperLimbVisibility(.hidden)  // Hide hands/controllers UI

    // Register the immersive space for XBVR VR video playback
    ImmersiveSpace(id: "XBVRPlayerSpace") {
      if let video = xbvrPlayerState.currentVideo {
        VRPlayerView(video: video)
          .environmentObject(xbvrPlayerState)
      }
    }
    .immersionStyle(selection: .constant(.full), in: .mixed, .progressive, .full)
    .upperLimbVisibility(.hidden)

    // Register the NEW GVR-style Metal-based VR player
    // This is the Moon Player-inspired implementation with proper Metal shaders
    // Use this instead of ImmersiveVideoSpace for better VR projection
    ImmersiveSpace(id: "GVRPlayerSpace") {
      GVRStylePlayerView()
        .environmentObject(appModel)
        .environmentObject(navigationModel)
        .persistentSystemOverlays(.hidden)
    }
    .immersionStyle(selection: .constant(.full), in: .full)
    .upperLimbVisibility(.hidden)
  }
}
