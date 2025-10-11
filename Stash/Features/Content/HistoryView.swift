import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appModel: AppModel

  private let columns = [
    GridItem(.adaptive(minimum: 350, maximum: 500), spacing: 20)
  ]

  var body: some View {
    ScrollView {
      if appModel.watchHistory.isEmpty {
        VStack(spacing: 20) {
          Spacer().frame(height: 100)

          Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 80))
            .foregroundColor(.gray.opacity(0.5))

          Text("No Watch History")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)

          Text("Videos you watch will appear here")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

          Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
      } else {
        VStack(alignment: .leading, spacing: 20) {
          // Header with count and clear button
          HStack {
            Text("Watch History")
              .font(.largeTitle)
              .fontWeight(.bold)

            Spacer()

            Button(action: {
              appModel.watchHistory.removeAll()
            }) {
              Label("Clear History", systemImage: "trash")
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
          }
          .padding(.horizontal)
          .padding(.top)

          // History grid
          LazyVGrid(columns: columns, spacing: 20) {
            ForEach(appModel.watchHistory.reversed()) { scene in
              SceneRow(scene: scene, allScenes: appModel.watchHistory)
            }
          }
          .padding(.horizontal)
          .padding(.bottom, 40)
        }
      }
    }
    .background(.ultraThinMaterial)
    .navigationTitle("History")
    .onDisappear {
      // Stop all preview players when navigating away from history
      print("🔇 HistoryView disappeared - stopping all preview players")
      GlobalVideoManager.shared.stopAllPreviews()
    }
    .onChange(of: appModel.isShowingPlayer) { _, isShowing in
      // Stop all previews when full-screen player opens
      if isShowing {
        print("🔇 Full-screen player opened - stopping all preview players in history")
        GlobalVideoManager.shared.stopAllPreviews()
      }
    }
  }
}

#Preview {
  HistoryView()
    .environmentObject(AppModel())
}
