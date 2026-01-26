import SwiftUI

struct TagSelectionView: View {
  let scene: StashScene
  @StateObject private var api = StashAPI()
  @Environment(\.dismiss) private var dismiss

  @State private var searchText = ""
  @State private var selectedTagIDs: Set<String>
  @State private var searchResults: [StashScene.Tag] = []
  @State private var isSearching = false
  @State private var errorMessage: String?
  @State private var showError = false

  init(scene: StashScene) {
    self.scene = scene
    _selectedTagIDs = State(initialValue: Set(scene.tags?.map { $0.id } ?? []))
  }

  var body: some View {
    List {
      Section {
        ForEach(scene.tags ?? []) { tag in
          HStack {
            Text(tag.name)
            Spacer()
            Button(action: {
              selectedTagIDs.remove(tag.id)
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
            }
          }
        }
      } header: {
        Text("Selected Tags")
      }

      Section {
        TextField("Search tags...", text: $searchText)
          .textFieldStyle(.plain)
          .onChange(of: searchText) { _, newValue in
            Task {
              do {
                searchResults = try await api.searchTags(query: newValue)
                isSearching = true
              } catch {
                errorMessage = error.localizedDescription
                showError = true
              }
            }
          }

        if isSearching {
          ForEach(searchResults) { tag in
            Button(action: { selectedTagIDs.insert(tag.id) }) {
              HStack {
                Text(tag.name)
                Spacer()
                if selectedTagIDs.contains(tag.id) {
                  Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      } header: {
        Text("Add Tags")
      }
    }
    .navigationTitle("Edit Tags")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { saveChanges() }
      }
    }
    .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
      Button("OK", role: .cancel) {}
    } message: { error in
      Text(error)
    }
  }

  private func saveChanges() {
    Task {
      do {
        _ = try await api.updateScene(id: scene.id, tagIds: Array(selectedTagIDs))
        await MainActor.run {
          dismiss()
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }
}
