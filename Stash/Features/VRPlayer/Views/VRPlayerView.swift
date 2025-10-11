import AVFoundation
import Metal
import MetalKit
import RealityKit
import SwiftUI

struct VRPlayerView: View {
  @StateObject private var viewModel = VRPlayerViewModel()
  @EnvironmentObject private var xbvrPlayerState: XBVRPlayerState
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  let video: XBVRVideo

  @State private var rootEntity = Entity()
  @State private var videoEntity: ModelEntity?
  @State private var videoMaterial: VideoMaterial?
  @State private var showInitialGuide = false  // Disabled in immersive mode
  @State private var contentReference: RealityViewContent?

  var body: some View {
    ZStack {
      // DEBUG: Bright overlay to verify view is showing
      Color.blue.opacity(0.3)
        .ignoresSafeArea()
        .onAppear {
          print("🔵 VRPlayerView body appeared - blue overlay should be visible")
        }

      // RealityKit content
      RealityView { content in
        print("🎨 RealityView content closure called")
        content.add(rootEntity)
        print("🎨 Root entity added to RealityView content")
        print("🎨 RootEntity children count: \(rootEntity.children.count)")

        // Store content reference for later use
        contentReference = content

        // If player is already available, set up video environment immediately
        if viewModel.player != nil {
          print(
            "🎬 Player already available, setting up video environment in RealityView make closure")
          setupVideoEnvironment(in: content)
        }
      } update: { content in
        updateVideoEnvironment(in: content)
      }
      .ignoresSafeArea()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.red.opacity(0.1))
      .onChange(of: viewModel.player) { _, newPlayer in
        if newPlayer != nil, let content = contentReference {
          print("🎬 Player changed, setting up video environment")
          setupVideoEnvironment(in: content)
        }
      }
      .onTapGesture {
        viewModel.toggleControls()
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            handleDragGesture(value)
          }
      )

      // Control overlays - Always show in immersive mode
      VStack {
        Spacer()

        // Main controls
        if viewModel.shouldShowControls {
          VRVideoControlsOverlay(viewModel: viewModel)
            .transition(.move(edge: .bottom).combined(with: .opacity))

          // Adjustment panels
          if viewModel.showAdjustmentPanel {
            VideoAdjustmentPanel(
              adjustments: $viewModel.videoAdjustments,
              onPresetSelected: { preset in
                viewModel.applyVideoAdjustments(preset)
              },
              onReset: {
                viewModel.videoAdjustments = .default
              }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }

          if viewModel.showSpatialControls {
            SpatialControlsView(
              settings: $viewModel.spatialSettings,
              onPresetSelected: { preset in
                viewModel.applySpatialSettings(preset)
              },
              onReset: {
                viewModel.spatialSettings = .default
              }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        } else {
          // Show minimal close button when controls are hidden
          HStack {
            Spacer()
            Button(action: {
              Task {
                await dismissImmersiveSpace()
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
                .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding()
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowControls)

      // Loading indicator
      if viewModel.isLoading {
        VStack {
          ProgressView()
            .scaleEffect(2.0)
            .progressViewStyle(CircularProgressViewStyle(tint: .white))

          Text("Loading VR Video...")
            .foregroundColor(.white)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
      }

      // Error overlay
      if let error = viewModel.error {
        VStack {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 50))
            .foregroundColor(.red)

          Text("Playback Error")
            .font(.headline)
            .foregroundColor(.white)

          Text(error.localizedDescription)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()

          Button("Retry") {
            Task {
              await viewModel.loadVideo(video)
            }
          }
          .buttonStyle(.borderedProminent)

          Button("Close") {
            Task {
              await dismissImmersiveSpace()
            }
          }
          .buttonStyle(.bordered)
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
      }

      // Initial guide overlay
      if showInitialGuide {
        InitialGuideOverlay {
          withAnimation {
            showInitialGuide = false
          }
        }
      }
    }
    .task {
      await viewModel.loadVideo(video)
    }
    .onDisappear {
      cleanup()
    }
  }

  // MARK: - Video Environment Setup

  private func setupVideoEnvironment(in content: RealityViewContent) {
    Task { @MainActor in
      guard let player = viewModel.player else {
        print("❌ setupVideoEnvironment: No player available")
        return
      }

      // Wait for player to be ready
      guard let playerItem = player.currentItem else {
        print("❌ No player item available")
        return
      }

      print("🎨 Setting up video environment, player status: \(playerItem.status.rawValue)")

      // NOTE: Following Stash pattern - don't wait for ready state
      // Just proceed with VideoMaterial creation even if status is not ready
      // The player will start playing audio immediately and video will appear when ready
      if playerItem.status != .readyToPlay {
        print(
          "⏳ Player not ready yet (status: \(playerItem.status.rawValue)), but continuing anyway..."
        )
      }

      print("🎨 Creating VideoMaterial...")

      // Create video material with error handling
      do {
        videoMaterial = try VideoMaterial(avPlayer: player)
        print("✅ VideoMaterial created successfully")
      } catch {
        print("❌ Failed to create VideoMaterial: \(error)")
        return
      }

      // Create video sphere/surface with content reference
      createVideoSurface(in: content)

      print("✅ VR video environment setup complete")
    }
  }

  private func updateVideoEnvironment(in content: RealityViewContent) {
    // Update when spatial settings or video format changes
    updateVideoSurface()
  }

  private func createVideoSurface(in content: RealityViewContent) {
    guard let videoMaterial = videoMaterial else {
      print("❌ createVideoSurface: No video material available")
      return
    }

    print("🎨 Creating video surface...")

    // Remove existing entity
    videoEntity?.removeFromParent()

    // Create geometry based on video type and format
    let mesh = createVideoMesh()
    print("🎨 Mesh created for video type: \(viewModel.videoType)")

    // Apply video adjustments to material if needed
    let finalMaterial = applyVideoAdjustments(to: videoMaterial)

    // Create model entity
    videoEntity = ModelEntity(mesh: mesh, materials: [finalMaterial])
    print("🎨 ModelEntity created")

    // DEBUG: Also create a visible test sphere to verify RealityKit is working
    let testSphere = ModelEntity(
      mesh: .generateSphere(radius: 0.3),
      materials: [SimpleMaterial(color: .red, isMetallic: false)]
    )
    testSphere.position = SIMD3<Float>(0, 0, -2)  // Red sphere at 2 meters
    rootEntity.addChild(testSphere)
    print("🔴 Added red test sphere at (0, 0, -2) to verify rendering")

    // Apply spatial transforms
    updateSpatialTransform()

    // Add to scene
    if let videoEntity = videoEntity {
      // DEBUG: Make it bright and obvious
      videoEntity.position = SIMD3<Float>(0, 0, -3)  // Much closer - 3 meters
      rootEntity.addChild(videoEntity)
      print("✅ Video entity added to scene at position: \(videoEntity.position)")
      print("✅ Video entity scale: \(videoEntity.scale)")
      print("✅ Video entity has \(videoEntity.model?.materials.count ?? 0) materials")
      print("✅ RootEntity now has \(rootEntity.children.count) children")
    } else {
      print("❌ Failed to create video entity")
    }
  }

  private func updateVideoSurface() {
    guard let videoEntity = videoEntity else { return }

    // Update spatial transform
    updateSpatialTransform()

    // Update material if adjustments changed
    if let videoMaterial = videoMaterial {
      let updatedMaterial = applyVideoAdjustments(to: videoMaterial)
      videoEntity.model?.materials = [updatedMaterial]
    }
  }

  private func createVideoMesh() -> MeshResource {
    let videoType = viewModel.videoType
    let spatialSettings = viewModel.spatialSettings

    switch videoType {
    case .vr360:
      return createSphereMesh(spatialSettings: spatialSettings)
    case .vr180:
      return create180Mesh(spatialSettings: spatialSettings)
    case .flat:
      return createPlaneMesh(spatialSettings: spatialSettings)
    }
  }

  private func createSphereMesh(spatialSettings: SpatialSettings) -> MeshResource {
    // Create a sphere for 360° content
    let radius = spatialSettings.distance
    return .generateSphere(radius: radius)
  }

  private func create180Mesh(spatialSettings: SpatialSettings) -> MeshResource {
    // Create a curved surface for 180° content
    let radius = spatialSettings.distance
    let segments = 32
    let fov = spatialSettings.horizontalFOVRadians

    var vertices: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    // Generate vertices for curved surface
    for vIdx in 0...segments / 2 {
      let vAngle = (Float(vIdx) / Float(segments / 2) - 0.5) * .pi / 2  // -45° to +45° vertical

      for hIdx in 0...segments {
        let hAngle = (Float(hIdx) / Float(segments) - 0.5) * fov  // Horizontal FOV

        // Calculate 3D position
        let x = radius * sin(hAngle) * cos(vAngle)
        let y = radius * sin(vAngle)
        let z = -radius * cos(hAngle) * cos(vAngle)

        vertices.append(SIMD3<Float>(x, y, z))

        // Normal pointing inward
        let normal = normalize(SIMD3<Float>(-x, -y, z))
        normals.append(normal)

        // UV coordinates based on stereo format
        let u = Float(hIdx) / Float(segments)
        let v = 1.0 - Float(vIdx) / Float(segments / 2)

        switch viewModel.videoFormat {
        case .sideBySide:
          uvs.append(SIMD2<Float>(u * 0.5, v))
        case .overUnder:
          uvs.append(SIMD2<Float>(u, v * 0.5))
        case .mono:
          uvs.append(SIMD2<Float>(u, v))
        }
      }
    }

    // Generate indices
    for vIdx in 0..<segments / 2 {
      for hIdx in 0..<segments {
        let topLeft = vIdx * (segments + 1) + hIdx
        let topRight = topLeft + 1
        let bottomLeft = (vIdx + 1) * (segments + 1) + hIdx
        let bottomRight = bottomLeft + 1

        // Triangle 1
        indices.append(UInt32(topLeft))
        indices.append(UInt32(bottomLeft))
        indices.append(UInt32(topRight))

        // Triangle 2
        indices.append(UInt32(topRight))
        indices.append(UInt32(bottomLeft))
        indices.append(UInt32(bottomRight))
      }
    }

    // Create mesh descriptor
    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = MeshBuffer(vertices)
    meshDescriptor.textureCoordinates = MeshBuffer(uvs)
    meshDescriptor.normals = MeshBuffer(normals)
    meshDescriptor.primitives = .triangles(indices)

    do {
      return try MeshResource.generate(from: [meshDescriptor])
    } catch {
      print("❌ Error creating 180° mesh: \(error)")
      return .generateSphere(radius: spatialSettings.distance)
    }
  }

  private func createPlaneMesh(spatialSettings: SpatialSettings) -> MeshResource {
    // Create a flat plane for 2D content
    let width: Float = 3.0 * spatialSettings.zoom
    let height: Float = 1.69 * spatialSettings.zoom  // 16:9 aspect ratio

    return .generatePlane(width: width, height: height)
  }

  private func applyVideoAdjustments(to material: VideoMaterial) -> RealityFoundation.Material {
    // For now, return the original material
    // In a full implementation, this would create a custom material
    // with the Metal shaders we created
    return material
  }

  private func updateSpatialTransform() {
    guard let videoEntity = videoEntity else { return }

    let settings = viewModel.spatialSettings

    // Apply position
    videoEntity.position = settings.position

    // Apply rotation and orientation
    videoEntity.orientation = settings.orientation

    // Apply scale (zoom)
    videoEntity.scale = settings.scale
  }

  // MARK: - Gesture Handling

  private func handleDragGesture(_ value: DragGesture.Value) {
    let rotationSensitivity: Float = 0.01
    let deltaX = Float(value.translation.width) * rotationSensitivity

    // Update rotation in spatial settings
    var newSettings = viewModel.spatialSettings
    newSettings.rotationY += deltaX
    newSettings.validate()

    viewModel.applySpatialSettings(newSettings)
    viewModel.showControlsTemporarily()
  }

  // MARK: - Cleanup

  private func cleanup() {
    videoEntity?.removeFromParent()
    videoEntity = nil
    videoMaterial = nil
  }
}

// MARK: - Initial Guide Overlay

struct InitialGuideOverlay: View {
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text("VR Video Player")
        .font(.title)
        .fontWeight(.bold)

      VStack(alignment: .leading, spacing: 12) {
        GuideItem(
          icon: "hand.tap",
          text: "Tap to show/hide controls"
        )

        GuideItem(
          icon: "arrow.left.and.right",
          text: "Drag left/right to rotate view"
        )

        GuideItem(
          icon: "slider.horizontal.3",
          text: "Use adjustment panel for video settings"
        )

        GuideItem(
          icon: "move.3d",
          text: "Spatial controls for positioning"
        )

        GuideItem(
          icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
          text: "Toggle between side-by-side and over-under"
        )
      }

      Button("Got it!") {
        onDismiss()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(30)
    .background(Material.ultraThinMaterial)
    .cornerRadius(20)
    .padding()
    .frame(maxWidth: 500)
  }
}

struct GuideItem: View {
  let icon: String
  let text: String

  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundColor(.blue)
        .frame(width: 24)

      Text(text)
        .font(.body)
    }
  }
}

// MARK: - Preview

struct VRPlayerView_Previews: PreviewProvider {
  static var previews: some View {
    VRPlayerView(
      video: XBVRVideo(
        id: "preview",
        title: "Sample VR Video",
        duration: 1800,
        resolution: CGSize(width: 3840, height: 1920),
        videoType: .vr180,
        stereoMode: .sideBySide,
        streamURL: URL(string: "http://example.com/video.mp4")!
      )
    )
  }
}
