import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    VStack {
      Text("Dashboard")
        .font(.largeTitle)

      // Add dashboard content here
    }
  }
}

struct DashboardView_Previews: PreviewProvider {
  static var previews: some View {
    DashboardView()
      
      .environmentObject(NavigationModel())
  }
}
