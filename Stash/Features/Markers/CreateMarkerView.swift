import SwiftUI

struct CreateMarkerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var api: StashAPI
  @State private var primaryTagId: String = ""
  @State private var primaryTagName: String = ""
  @State private var seconds: String
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showError = false
  let sceneID: String
  let onMarkerCreated: () -> Void

  init(
    api: StashAPI, initialSeconds: String = "", sceneID: String = "",
    onMarkerCreated: @escaping () -> Void = {}
  ) {
    _api = State(initialValue: api)
    _seconds = State(initialValue: initialSeconds)
    self.sceneID = sceneID
    self.onMarkerCreated = onMarkerCreated
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Text("Timestamp:")
            Spacer()
            Text(formatTimestamp(seconds))
              .foregroundColor(.secondary)
          }
        }

        Section {
          Button(action: {
            Task {
              do {
                // Will implement tag search later
                showError = true
                errorMessage = "Tag selection not implemented yet"
              } catch {
                print("❌ Error loading tags: \(error)")
              }
            }
          }) {
            if primaryTagName.isEmpty {
              Text("Select Primary Tag")
                .foregroundColor(.accentColor)
            } else {
              Text(primaryTagName)
                .foregroundColor(.accentColor)
            }
          }
        }

        Section {
          Button(action: createMarker) {
            if isLoading {
              ProgressView()
            } else {
              Text("Create Marker")
            }
          }
          .disabled(isLoading || !isValid)
        }
      }
      .navigationTitle("Create Marker")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
        Button("OK", role: .cancel) {}
      } message: { error in
        Text(error)
      }
    }
  }

  private func formatTimestamp(_ timestamp: String) -> String {
    guard let seconds = Double(timestamp) else { return timestamp }
    let minutes = Int(seconds / 60)
    let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
    let milliseconds = Int((seconds * 1000).truncatingRemainder(dividingBy: 1000))
    return String(format: "%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
  }

  private var isValid: Bool {
    !seconds.isEmpty && !sceneID.isEmpty && !primaryTagId.isEmpty
  }

  private func createMarker() {
    // Will implement marker creation later
    showError = true
    errorMessage = "Marker creation not implemented yet"
  }
}
