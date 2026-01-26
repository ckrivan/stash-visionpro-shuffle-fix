import RealityKit
import SwiftUI

struct ImmersiveView: View {
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    RealityView { content in
      // Create a simple 3D entity
      let sphere = ModelEntity(
        mesh: .generateSphere(radius: 0.1),
        materials: [SimpleMaterial(color: .blue, isMetallic: true)]
      )

      // Position it in front of the user
      sphere.position = SIMD3(x: 0, y: 1.5, z: -3)

      // Add rotation animation
      sphere.components[RotationComponent.self] = RotationComponent()

      // Add entity to the content
      content.add(sphere)

      // Add continuous rotation animation using RealityKit's animation system
      let transform = sphere.transform
      let rotation = simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(0, 1, 0))
      sphere.move(
        to: transform.matrix * Transform(rotation: rotation).matrix,
        relativeTo: sphere.parent,
        duration: 2,
        timingFunction: .linear
      )
    }
    .gesture(
      SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
          print("Tapped at: \(value.location)")
        }
    )
  }
}

// Custom component for rotation
private struct RotationComponent: Component {
  var speed: Float = 1.0
}

struct ImmersiveView_Previews: PreviewProvider {
  static var previews: some View {
    ImmersiveView()
      
      .environmentObject(NavigationModel())
  }
}
