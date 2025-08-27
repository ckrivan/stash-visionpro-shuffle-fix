import SwiftUI

struct PerformersView: View {
  @EnvironmentObject private var api: StashAPI
  @State private var selectedFilter: PerformerFilter = .twoOrMore
  @State private var searchText = ""
  @State private var currentPage = 1
  @State private var isLoadingMore = false
  @State private var hasMorePages = true

  private let columns = [
    GridItem(.adaptive(minimum: 200), spacing: 16)
  ]

  var body: some View {
    ScrollView {
      // Filter picker
      Picker("Scene Count", selection: $selectedFilter) {
        Text("All").tag(PerformerFilter.all)
        Text("< 2 Scenes").tag(PerformerFilter.lessThanTwo)
        Text("2+ Scenes").tag(PerformerFilter.twoOrMore)
        Text("10+ Scenes").tag(PerformerFilter.tenOrMore)
      }
      .pickerStyle(.segmented)
      .padding()

      LazyVGrid(columns: columns, spacing: 16) {
        if api.isLoading && currentPage == 1 {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if api.performers.isEmpty {
          Text("No performers found")
            .foregroundStyle(.secondary)
        } else {
          ForEach(api.performers) { performer in
            NavigationLink(value: Route.performer(performer)) {
              PerformerCard(performer: performer)
            }
            .buttonStyle(.plain)
            .onAppear {
              if performer == api.performers.last && !isLoadingMore && hasMorePages {
                Task {
                  await loadMorePerformers()
                }
              }
            }
          }
        }

        if isLoadingMore {
          ProgressView()
            .gridCellColumns(1)
            .padding()
        }
      }
      .padding()
    }
    .navigationTitle("Performers")
    .searchable(text: $searchText)
    .onChange(of: selectedFilter) { _, _ in
      Task {
        await loadInitialPerformers()
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadInitialPerformers()
      }
    }
    .task {
      await loadInitialPerformers()
    }
  }

  private func loadInitialPerformers() async {
    currentPage = 1
    hasMorePages = true
    isLoadingMore = false
    await api.fetchPerformers(
      filter: selectedFilter, page: currentPage, appendResults: false, search: searchText)
  }

  private func loadMorePerformers() async {
    guard !isLoadingMore else { return }

    isLoadingMore = true
    currentPage += 1

    let previousCount = api.performers.count
    await api.fetchPerformers(
      filter: selectedFilter, page: currentPage, appendResults: true, search: searchText)

    isLoadingMore = false
    hasMorePages = api.performers.count > previousCount
  }
}

struct PerformerCard: View {
  let performer: StashScene.Performer

  var body: some View {
    VStack {
      if let imagePath = performer.image_path,
        let imageURL = URL(string: imagePath) {
        AsyncImage(url: imageURL) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Rectangle()
            .fill(.ultraThinMaterial)
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
      }

      Text(performer.name)
        .font(.headline)

      if let sceneCount = performer.scene_count {
        Text("\(sceneCount) scenes")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .hoverEffect(.lift)
  }
}

struct PerformersView_Previews: PreviewProvider {
  static var previews: some View {
    let api = StashAPI()
    api.preview = true
    api.performers = [StashScene.Performer.example]
    return PerformersView()
      .environmentObject(api)
      .environmentObject(NavigationModel())
  }
}
