import SwiftUI

struct TagEditorView: View {
  let scene: StashScene
  @StateObject private var api = StashAPI()
  @Environment(\.dismiss) private var dismiss

  @State private var searchText = ""
  @State private var selectedTags: Set<StashScene.Tag>
  @State private var searchResults: [StashScene.Tag] = []
  @State private var isSearching = false
  @State private var showingCreateTag = false
  @State private var newTagName = ""
  @State private var errorMessage: String?
  @State private var showError = false

  init(scene: StashScene) {
    self.scene = scene
    _selectedTags = State(initialValue: Set(scene.tags ?? []))
  }

  var body: some View {
    List {
      Section {
        ForEach(Array(selectedTags)) { tag in
          HStack {
            Text(tag.name)
            Spacer()
            Button(action: { selectedTags.remove(tag) }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
            }
          }
        }
      } header: {
        Text("Selected Tags")
      }

      Section {
        TextField("Search or create tag...", text: $searchText)
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
            Button(action: { selectedTags.insert(tag) }) {
              HStack {
                Text(tag.name)
                Spacer()
                if selectedTags.contains(tag) {
                  Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                }
              }
            }
          }

          if !searchResults.contains(where: { $0.name.lowercased() == searchText.lowercased() }) {
            Button(action: { showingCreateTag = true }) {
              Label("Create tag '\(searchText)'", systemImage: "plus")
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
    .alert("Create Tag", isPresented: $showingCreateTag) {
      TextField("Tag name", text: $newTagName)
      Button("Cancel", role: .cancel) {}
      Button("Create") { createTag() }
    } message: {
      Text("Enter a name for the new tag")
    }
  }

  private func createTag() {
    guard !newTagName.isEmpty else { return }

    Task {
      do {
        let newTag = try await api.createTag(name: newTagName)
        await MainActor.run {
          selectedTags.insert(newTag)
          searchText = ""
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }

  private func saveChanges() {
    Task {
      do {
        let tagIds = selectedTags.map { $0.id }
        _ = try await api.updateScene(id: scene.id, tagIds: tagIds)
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
