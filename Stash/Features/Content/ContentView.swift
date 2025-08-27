import SwiftUI

struct ContentView: View {
  @EnvironmentObject var appModel: AppModel
  @EnvironmentObject var navigationModel: NavigationModel
  var body: some View {
    if appModel.isConnected {
      MainVisionView()
        .onAppear {
            AppNotificationHandler.shared.setupRandomSceneObserver(appModel: appModel)
        }
    } else {
      ServerConnectionView(
        serverAddress: $appModel.serverAddress,
        apiKey: $appModel.apiKey,
        isConnected: $appModel.isConnected
      )
    }
  }
}

struct ServerConnectionView: View {
  @Binding var serverAddress: String
  @Binding var apiKey: String
  @Binding var isConnected: Bool
  @State private var isLoading = false
  @State private var errorMessage: String?

  // Hardcoded credentials
  private let hardcodedServerAddress = "http://192.168.86.100:9999"
  private let hardcodedApiKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

  var body: some View {
    VStack(spacing: 20) {
      Text("Connecting to Stash Server")
        .font(.largeTitle)
        .padding(.bottom, 20)

      VStack(alignment: .leading, spacing: 8) {
        Text("Server Address:")
          .foregroundColor(.secondary)
        Text(hardcodedServerAddress)
          .font(.system(.body, design: .monospaced))
          .padding()
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .padding(.horizontal)

      Text("Using saved credentials")
        .font(.caption)
        .foregroundColor(.secondary)

      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .padding()
      }

      if isLoading {
        VStack(spacing: 12) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            .scaleEffect(1.2)

          Text("Connecting...")
            .foregroundColor(.secondary)
        }
      } else {
        Button(action: testConnection) {
          HStack {
            Image(systemName: "arrow.clockwise")
            Text("Retry Connection")
          }
          .frame(minWidth: 200)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
    }
    .padding()
    .frame(width: 400)
    .onAppear {
      // Auto-connect when view appears
      if !isConnected && !isLoading {
        testConnection()
      }
    }
  }

  func testConnection() {
    isLoading = true
    errorMessage = nil

    // Use hardcoded credentials
    let formattedAddress = hardcodedServerAddress
    let currentApiKey = hardcodedApiKey

    // Update the bindings with hardcoded values
    serverAddress = formattedAddress
    apiKey = currentApiKey

    // Save the formatted server address and API key
    UserDefaults.standard.set(formattedAddress, forKey: "serverAddress")
    UserDefaults.standard.set(currentApiKey, forKey: "apiKey")

    print("🔄 Testing connection to \(formattedAddress) with hardcoded credentials")

    // Test the connection using the same method as the StashConnectionTest script
    Task {
      do {
        // Create a simple GraphQL query to check connection
        let query = """
          {
              "operationName": "FindPerformers",
              "variables": {
                  "filter": {
                      "page": 1,
                      "per_page": 1,
                      "sort": "name",
                      "direction": "ASC"
                  }
              },
              "query": "query FindPerformers($filter: FindFilterType) { findPerformers(filter: $filter) { count performers { id name } } }"
          }
          """

        guard let url = URL(string: "\(formattedAddress)/graphql") else {
          throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication using hardcoded API key
        request.setValue("Bearer \(currentApiKey)", forHTTPHeaderField: "Authorization")

        request.httpBody = query.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
          print("📝 Test connection status: \(httpResponse.statusCode)")

          if httpResponse.statusCode == 200 {
            // Connection successful
            await MainActor.run {
              isConnected = true
              isLoading = false
            }
          } else {
            // Server responded but with an error
            throw URLError(.badServerResponse)
          }
        } else {
          throw URLError(.badServerResponse)
        }
      } catch {
        print("❌ Connection test failed: \(error.localizedDescription)")
        await MainActor.run {
          errorMessage = "Connection failed: \(error.localizedDescription)"
          isLoading = false
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      
      .environmentObject(NavigationModel())
  }
}
