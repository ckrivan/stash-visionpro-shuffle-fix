import SwiftUI

struct ToggleImmersiveSpaceButton: View {
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel

  var body: some View {
    Button {
      Task {
        switch appModel.immersiveSpaceState {
        case .closed:
          appModel.immersiveSpaceState = .inTransition
          try? await openImmersiveSpace(id: "player")
          appModel.immersiveSpaceState = .open

        case .open:
          appModel.immersiveSpaceState = .inTransition
          await dismissImmersiveSpace()
          appModel.immersiveSpaceState = .closed

        case .inTransition:
          break
        }
      }
    } label: {
      Image(
        systemName: appModel.immersiveSpaceState == .open
          ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
    }
    .disabled(appModel.immersiveSpaceState == .inTransition)
  }
}

struct ToggleImmersiveSpaceButton_Previews: PreviewProvider {
  static var previews: some View {
    ToggleImmersiveSpaceButton()
      
      .environmentObject(NavigationModel())
  }
}
