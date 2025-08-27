import SwiftUI
import os.log

struct ConnectionView: View {
  @Binding var serverAddress: String
  @Binding var isConnected: Bool
  @State private var isAttemptingConnection = false
  @State private var showError = false
  @State private var errorMessage = ""

  // Hardcoded credentials - no user input needed
  private let hardcodedServerAddress = "http://192.168.86.100:9999"
  private let hardcodedApiKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "server.rack")
        .font(.system(size: 60))
        .foregroundColor(.accentColor)

      Text("Connecting to Stash Server")
        .font(.title2)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Server Address")
            .foregroundColor(.secondary)

          Text(hardcodedServerAddress)
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundColor(.primary)

          Text("Automatically connecting with saved credentials")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: 400)
      .padding(.horizontal)

      if isAttemptingConnection {
        VStack(spacing: 12) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            .scaleEffect(1.2)

          Text("Connecting...")
            .foregroundColor(.secondary)
        }
      } else {
        Button(action: attemptConnection) {
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
    .onAppear {
      // Auto-connect when view appears
      if !isConnected && !isAttemptingConnection {
        attemptConnection()
      }
    }
    .padding()
    .alert("Connection Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private func attemptConnection() {
    // Use hardcoded server address
    let address = hardcodedServerAddress

    Logger.connection.info("🔄 Attempting connection to: \(address)")

    guard let url = URL(string: address) else {
      Logger.connection.error("❌ Invalid server address: \(address)")
      errorMessage = "Invalid server address"
      showError = true
      return
    }

    isAttemptingConnection = true

    var request = URLRequest(url: url.appendingPathComponent("graphql"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add API key authentication
    request.setValue("Bearer \(hardcodedApiKey)", forHTTPHeaderField: "Authorization")

    let query = """
      {
          "query": "{ stats { scene_count } }"
      }
      """

    request.httpBody = query.data(using: .utf8)

    Task {
      do {
        let (data, response) = try await URLSession.shared.data(for: request)

        await MainActor.run {
          guard let httpResponse = response as? HTTPURLResponse else {
            Logger.connection.error("❌ Invalid response type")
            errorMessage = "Invalid response type"
            showError = true
            isAttemptingConnection = false
            return
          }

          switch httpResponse.statusCode {
          case 200:
            Logger.connection.info("✅ Successfully connected to server")
            UserDefaults.standard.set(address, forKey: "serverAddress")
            serverAddress = address  // Update the binding
            isConnected = true
          case 401:
            Logger.connection.error("🔒 Authentication required")
            errorMessage = "Authentication required"
            showError = true
          default:
            Logger.connection.error("❌ Server returned error: \(httpResponse.statusCode)")
            errorMessage = "Server returned error: \(httpResponse.statusCode)"
            showError = true
          }

          isAttemptingConnection = false
        }
      } catch {
        await MainActor.run {
          Logger.connection.error("❌ Connection failed: \(error.localizedDescription)")
          errorMessage = "Connection failed: \(error.localizedDescription)"
          showError = true
          isAttemptingConnection = false
        }
      }
    }
  }
}
