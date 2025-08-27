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
        let startTime = userInfo["startTime"] as? Double {
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

@main
struct StashApp: App {
  @StateObject private var appModel = AppModel()
  @StateObject private var navigationModel = NavigationModel()

  

  var body: some SwiftUI.Scene {
    WindowGroup {
      ContentView()
        .environmentObject(appModel)
        .environmentObject(navigationModel)
        .onChange(of: UIApplication.shared.applicationState) { newState in
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
    }
    .immersionStyle(selection: .constant(.full), in: .full)
  }
}
