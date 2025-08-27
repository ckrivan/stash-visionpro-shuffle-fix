import SwiftUI

struct TagSelectorSheet: View {
  let availableTags: [StashScene.Tag]
  @Binding var selectedTagIds: Set<String>
  @Binding var selectedTagId: String?
  @Binding var isMultiTagMode: Bool
  let onSelectionChanged: () -> Void
  
  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""
  @State private var allMarkerTags: [StashScene.Tag] = []
  @State private var isLoadingTags = false
  @StateObject private var api = StashAPI()
  
  private var filteredTags: [StashScene.Tag] {
    let tagsToFilter = allMarkerTags.isEmpty ? availableTags : allMarkerTags
    
    if searchText.isEmpty {
      return tagsToFilter
    } else {
      return tagsToFilter.filter { tag in
        tag.name.localizedCaseInsensitiveContains(searchText)
      }
    }
  }
  
  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Search bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
          TextField("Search tags...", text: $searchText)
        }
        .padding()
        .background(.ultraThinMaterial)
        
        // Content
        if isLoadingTags {
          VStack(spacing: 16) {
            ProgressView()
            Text("Loading all marker tags...")
              .font(.headline)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredTags.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "tag.slash")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("No tags found")
              .font(.headline)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List {
            Section {
              ForEach(filteredTags, id: \.id) { tag in
                Button(action: { selectTag(tag) }) {
                  HStack {
                    Text(tag.name)
                      .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isMultiTagMode {
                      if selectedTagIds.contains(tag.id) {
                        Image(systemName: "checkmark.circle.fill")
                          .foregroundColor(.blue)
                      } else {
                        Image(systemName: "circle")
                          .foregroundColor(.secondary)
                      }
                    } else {
                      if selectedTagId == tag.id {
                        Image(systemName: "checkmark")
                          .foregroundColor(.blue)
                      }
                    }
                  }
                }
                .buttonStyle(.plain)
              }
            } header: {
              HStack {
                Text("\(filteredTags.count) tags")
                  .textCase(nil)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                
                Spacer()
                
                if isMultiTagMode && !selectedTagIds.isEmpty {
                  Button("Clear All") {
                    selectedTagIds.removeAll()
                    onSelectionChanged()
                  }
                  .font(.caption)
                  .foregroundColor(.red)
                }
              }
            }
          }
        }
      }
      .navigationTitle(isMultiTagMode ? "Select Tags" : "Select Tag")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
            onSelectionChanged()
          }
        }
        
        ToolbarItem(placement: .primaryAction) {
          Button(action: {
            isMultiTagMode.toggle()
            if !isMultiTagMode {
              // When switching to single-tag mode, keep only the first selected tag
              if let firstTagId = selectedTagIds.first {
                selectedTagId = firstTagId
                selectedTagIds.removeAll()
                selectedTagIds.insert(firstTagId)
              } else {
                selectedTagId = nil
                selectedTagIds.removeAll()
              }
            } else {
              // When switching to multi-tag mode, add current tag to set
              if let currentTagId = selectedTagId {
                selectedTagIds.insert(currentTagId)
              }
            }
          }) {
            Text(isMultiTagMode ? "Single" : "Multi")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(isMultiTagMode ? .blue : .gray, in: Capsule())
              .foregroundColor(.white)
          }
        }
      }
    }
    .frame(minWidth: 400, minHeight: 500)
    .task {
      await loadAllMarkerTags()
    }
  }
  
  private func loadAllMarkerTags() async {
    isLoadingTags = true
    
    do {
      let markerTags = try await api.fetchMarkerTags()
      await MainActor.run {
        self.allMarkerTags = markerTags
        print("📊 Loaded \(markerTags.count) marker tags for selection")
      }
    } catch {
      print("❌ Error loading marker tags: \(error)")
      // Fallback to using availableTags if API call fails
      await MainActor.run {
        self.allMarkerTags = []
      }
    }
    
    isLoadingTags = false
  }
  
  private func selectTag(_ tag: StashScene.Tag) {
    if isMultiTagMode {
      if selectedTagIds.contains(tag.id) {
        selectedTagIds.remove(tag.id)
      } else {
        selectedTagIds.insert(tag.id)
      }
    } else {
      selectedTagId = tag.id
      selectedTagIds.removeAll()
      dismiss()
      onSelectionChanged()
    }
  }
}