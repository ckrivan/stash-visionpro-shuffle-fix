//
//  GVRStylePlayerView.swift
//  Stash VR Player - Moon Player Style VR Playback
//
//  Uses Metal-based rendering for proper 180°/360° VR video playback with direct streaming.
//  Replaces the failed RealityKit UV mapping approach with proven Metal shader technique.
//

import AVFoundation
import RealityKit
import SwiftUI

/// Moon Player-style VR player using Metal rendering
/// Supports: SBS/OU/Fisheye, 180°/360°, direct streaming with HLS fallback
struct GVRStylePlayerView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    // Video player and renderer
    @StateObject private var metalRenderer = MetalVRRenderer()
    @State private var videoPlayer: AVPlayer?
    @State private var api = StashAPI()

    // VR format detection and configuration
    @State private var vrFormat: MetalVRFormat = .sideBySide
    @State private var vrProjection: MetalVRProjection = .projection180
    @State private var isVRContent = true

    // Gesture control state
    @State private var zoom: Float = 1.0
    @State private var rotation: Float = 0.0
    @State private var tilt: Float = 0.0
    @State private var baseRotation: Float = 0.0
    @State private var baseTilt: Float = 0.0

    // UI state
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var debugMessage = "Initializing GVR player..."
    @State private var isLoading = true
    @State private var showGuide = true

    // Metal rendering state
    @State private var metalLayer: CAMetalLayer?
    @State private var displayLink: CADisplayLink?

    var body: some View {
        ZStack {
            // RealityKit immersive space
            RealityView { content in
                await setupImmersiveSpace(content)
            }
            .ignoresSafeArea()

            // Control overlay
            if showControls {
                VStack {
                    Spacer()

                    // Main controls
                    HStack(spacing: 20) {
                        // Exit button
                        Button(action: {
                            cleanup()
                            Task {
                                try? await dismissImmersiveSpace()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        // Play/Pause
                        Button(action: {
                            if videoPlayer?.timeControlStatus == .playing {
                                videoPlayer?.pause()
                            } else {
                                videoPlayer?.play()
                            }
                        }) {
                            Image(
                                systemName: videoPlayer?.timeControlStatus == .playing
                                    ? "pause.circle.fill" : "play.circle.fill"
                            )
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        // Format picker
                        Menu {
                            Button("SBS 180°") {
                                vrFormat = .sideBySide
                                vrProjection = .projection180
                                updateRendererFormat()
                            }
                            Button("SBS 360°") {
                                vrFormat = .sideBySide
                                vrProjection = .projection360
                                updateRendererFormat()
                            }
                            Button("OU 180°") {
                                vrFormat = .overUnder
                                vrProjection = .projection180
                                updateRendererFormat()
                            }
                            Button("OU 360°") {
                                vrFormat = .overUnder
                                vrProjection = .projection360
                                updateRendererFormat()
                            }
                            Button("Fisheye 180°") {
                                vrFormat = .fisheye
                                vrProjection = .projection180
                                updateRendererFormat()
                            }
                            Button("Fisheye 360°") {
                                vrFormat = .fisheye
                                vrProjection = .projection360
                                updateRendererFormat()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                Text(formatDescription)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Status indicator
                        if videoPlayer?.timeControlStatus == .playing {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Playing")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .cornerRadius(16)
                        }

                        // Reset view button
                        Button(action: resetView) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset View")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.blue.opacity(0.7))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                }
            }

            // Loading indicator
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text(debugMessage)
                        .foregroundColor(.white)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
            }

            // Initial guide
            if showGuide {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Text("GVR-Style VR Player")
                            .font(.title2)
                            .bold()

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Tap to show/hide controls", systemImage: "hand.tap")
                            Label("Drag horizontally to rotate", systemImage: "arrow.left.and.right")
                            Label("Drag vertically to tilt", systemImage: "arrow.up.and.down")
                            Label("Pinch to zoom in/out", systemImage: "hand.pinch")
                                .foregroundColor(.blue)
                            Label("Double-tap Reset to recenter", systemImage: "arrow.counterclockwise")
                        }
                        .font(.body)

                        Button("Got it!") {
                            withAnimation {
                                showGuide = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                    .frame(maxWidth: 500)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(30)

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            scheduleControlsHide()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    handleDragGesture(value)
                }
                .onEnded { _ in
                    baseRotation = rotation
                    baseTilt = tilt
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    zoom = Float(value.magnification)
                    zoom = max(0.5, min(3.0, zoom))
                    metalRenderer.zoom = zoom
                }
        )
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Setup

    private func setupImmersiveSpace(_ content: RealityViewContent) async {
        debugMessage = "Setting up Metal VR renderer..."

        // Metal renderer is already initialized via @StateObject
        // Just wait for it to be ready
        guard metalRenderer.isReady else {
            debugMessage = "Waiting for Metal renderer..."
            return
        }

        debugMessage = "Metal renderer ready!"
        isLoading = false
    }

    private func setupPlayer() {
        guard let currentScene = appModel.currentScene else {
            debugMessage = "No scene selected"
            return
        }

        debugMessage = "Loading scene: \(currentScene.title ?? "Untitled")"

        // Detect VR format from tags
        detectVRFormat(from: currentScene)

        // Set up video player with direct streaming
        Task {
            do {
                debugMessage = "Requesting stream URL..."

                // Prefer direct streaming (useHLS: false) for best performance
                // API will automatically fall back to HLS for HEVC/problematic codecs
                guard let request = await api.getStreamRequest(
                    forSceneID: currentScene.id,
                    useHLS: false  // Prefer direct streaming like Moon Player
                ) else {
                    debugMessage = "Failed to get stream URL"
                    return
                }

                guard let url = request.url else {
                    debugMessage = "Invalid stream URL"
                    return
                }

                debugMessage = "Streaming from: \(url.absoluteString)"
                print("🎬 GVR Player: Streaming from \(url.absoluteString)")

                // Create AVPlayer with enhanced configuration
                let asset = AVURLAsset(url: url, options: [
                    "AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:],
                    "AVURLAssetAllowsExpensiveNetworkAccess": true,
                    "AVURLAssetUsesNSURLSessionKey": true,
                ])

                let playerItem = AVPlayerItem(asset: asset)
                playerItem.preferredForwardBufferDuration = 60  // Large buffer for VR

                let player = AVPlayer(playerItem: playerItem)
                player.automaticallyWaitsToMinimizeStalling = false

                await MainActor.run {
                    videoPlayer = player

                    // Attach player to Metal renderer
                    metalRenderer.attachToPlayer(player)

                    // Start playback
                    player.play()

                    debugMessage = "Playback started!"
                    isLoading = false

                    print("✅ GVR Player: Video playback started")
                }
            } catch {
                debugMessage = "Error: \(error.localizedDescription)"
                print("❌ GVR Player error: \(error)")
            }
        }
    }

    private func detectVRFormat(from scene: StashScene) {
        let tagNames = scene.tags?.map { $0.name.lowercased() } ?? []
        let title = (scene.title ?? "").lowercased()

        // Detect 180 vs 360
        let is180 = tagNames.contains { $0.contains("180") } || title.contains("180")
        let is360 = tagNames.contains { $0.contains("360") } || title.contains("360")

        // Detect fisheye
        let isFisheye = tagNames.contains {
            $0.contains("fisheye") || $0.contains("eac")
        } || title.contains("fisheye")

        // Detect SBS vs OU
        let isOverUnder = tagNames.contains {
            $0.contains("over-under") || $0.contains("tb") || $0.contains("ou")
        } || title.contains("tb") || title.contains("ou")

        let isSideBySide = tagNames.contains {
            $0.contains("side-by-side") || $0.contains("sbs")
        } || title.contains("sbs")

        // Set format
        if isFisheye {
            vrFormat = .fisheye
            vrProjection = is360 ? .projection360 : .projection180
        } else if isOverUnder {
            vrFormat = .overUnder
            vrProjection = is360 ? .projection360 : .projection180
        } else if isSideBySide {
            vrFormat = .sideBySide
            vrProjection = is360 ? .projection360 : .projection180
        } else {
            // Default to SBS 180
            vrFormat = .sideBySide
            vrProjection = is360 ? .projection360 : .projection180
        }

        updateRendererFormat()

        print("🎬 GVR Player: Detected format: \(formatDescription)")
    }

    // MARK: - Gesture Handling

    private func handleDragGesture(_ value: DragGesture.Value) {
        // Horizontal drag = rotation
        let rotationDelta = Float(value.translation.width) * 0.005
        rotation = baseRotation + rotationDelta

        // Vertical drag = tilt
        let tiltDelta = Float(value.translation.height) * 0.005
        tilt = baseTilt - tiltDelta  // Negative for natural movement
        tilt = max(-0.785, min(0.785, tilt))  // Clamp to ±45°

        // Update renderer
        metalRenderer.rotation = rotation
        metalRenderer.tilt = tilt

        // Show controls during gesture
        withAnimation {
            showControls = true
        }
        scheduleControlsHide()
    }

    private func resetView() {
        withAnimation {
            zoom = 1.0
            rotation = 0.0
            tilt = 0.0
            baseRotation = 0.0
            baseTilt = 0.0

            metalRenderer.zoom = zoom
            metalRenderer.rotation = rotation
            metalRenderer.tilt = tilt
        }
    }

    // MARK: - Helper Methods

    private func updateRendererFormat() {
        metalRenderer.format = vrFormat
        metalRenderer.projection = vrProjection
        print("🎬 Updated renderer format: \(formatDescription)")
    }

    private var formatDescription: String {
        let formatStr = switch vrFormat {
        case .mono: "Mono"
        case .sideBySide: "SBS"
        case .overUnder: "OU"
        case .fisheye: "Fisheye"
        }

        let projectionStr = vrProjection == .projection180 ? "180°" : "360°"
        return "\(formatStr) \(projectionStr)"
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()

        if !showGuide {
            hideControlsTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation {
                            showControls = false
                        }
                    }
                }
            }
        }
    }

    private func cleanup() {
        videoPlayer?.pause()
        videoPlayer?.replaceCurrentItem(with: nil)
        videoPlayer = nil

        metalRenderer.cleanup()

        hideControlsTask?.cancel()

        print("🧹 GVR Player cleaned up")
    }
}
