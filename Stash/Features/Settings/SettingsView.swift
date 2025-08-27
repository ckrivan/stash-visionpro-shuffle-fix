import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var stashAPI: StashAPI
  @State private var isTestingConnection = false
  @State private var connectionStatus: String?
  @State private var showError = false
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("Server Settings") {
        TextField("Server Address", text: $appModel.serverAddress)
          .textFieldStyle(.plain)
          .autocapitalization(.none)
          .disableAutocorrection(true)

        TextField("API Key", text: $appModel.apiKey)
          .textFieldStyle(.plain)
          .autocapitalization(.none)
          .disableAutocorrection(true)

        Button(action: testConnection) {
          if isTestingConnection {
            ProgressView()
          } else {
            Text("Test Connection")
          }
        }
        .disabled(appModel.serverAddress.isEmpty || isTestingConnection)

        if let status = connectionStatus {
          Text(status)
            .foregroundStyle(status.contains("Success") ? .green : .red)
        }
      }

      Section("VR Playback") {
        Text(
          "The app includes features to enhance your VR viewing experience, including a shuffle feature that lets you randomly jump to different videos at random timestamps."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
      Button("OK", role: .cancel) {}
    } message: { error in
      Text(error)
    }
  }

  func testConnection() {
    guard !appModel.serverAddress.isEmpty else { return }

    isTestingConnection = true
    connectionStatus = nil

    Task {
      do {
        try await stashAPI.fetchScenes()
        await MainActor.run {
          connectionStatus = "Success! Connected to server"
          isTestingConnection = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showError = true
          isTestingConnection = false
        }
      }
    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    let api = StashAPI()
    api.preview = true
    return SettingsView()
      .environmentObject(api)
  }
}
