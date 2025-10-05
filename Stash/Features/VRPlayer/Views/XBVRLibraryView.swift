import SwiftUI

struct XBVRLibraryView: View {
  @StateObject private var xbvrService = XBVRService.shared
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  @State private var videos: [XBVRVideo] = []
  @State private var isLoading = false
  @State private var error: Error?
  @State private var searchText = ""
  @State private var selectedVideo: XBVRVideo?
  @State private var showingPlayer = false
  @State private var currentPage = 1
  @State private var hasMorePages = true

  // Connection settings
  @State private var showConnectionSettings = false
  @State private var serverURL = "http://192.168.86.100:9998"
  @State private var apiKey = ""

  var filteredVideos: [XBVRVideo] {
    if searchText.isEmpty {
      return videos
    } else {
      return videos.filter { video in
        video.title.localizedCaseInsensitiveContains(searchText)
          || video.tags?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) == true
          || video.performers?.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            == true
      }
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        if xbvrService.isConnected {
          // Main content
          videoLibraryContent
        } else {
          // Connection setup
          connectionSetupView
        }

        // Loading overlay - visionOS 2.6
        if isLoading && videos.isEmpty {
          ProgressView("Loading XBVR videos...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .glassBackgroundEffect()
        }
      }
      .navigationTitle("XBVR Library")
      .toolbar {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
          if xbvrService.isConnected {
            Button {
              Task { await loadRandomVideo() }
            } label: {
              Label("Random Video", systemImage: "shuffle")
            }

            Button {
              Task { await refreshVideos() }
            } label: {
              Label("Refresh", systemImage: "arrow.clockwise")
            }
          }

          Button {
            showConnectionSettings = true
          } label: {
            Label("Settings", systemImage: "gearshape")
              .foregroundColor(xbvrService.isConnected ? .primary : .red)
          }
        }
      }
      .searchable(text: $searchText, prompt: "Search videos...")
      .onAppear {
        if xbvrService.isConnected && videos.isEmpty {
          Task { await loadVideos() }
        } else if !xbvrService.isConnected {
          // Try to connect automatically with hardcoded settings
          Task { await connectToXBVR() }
        }
      }
      .sheet(isPresented: $showConnectionSettings) {
        connectionSettingsSheet
      }
      .sheet(item: $selectedVideo) { video in
        VRPlayerView(video: video)
      }
    }
  }

  // MARK: - Video Library Content

  private var videoLibraryContent: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
        ], spacing: 16
      ) {
        ForEach(filteredVideos) { video in
          XBVRVideoCard(video: video) {
            selectedVideo = video
            showingPlayer = true
          }
          .onAppear {
            // Load more when approaching end
            if video == filteredVideos.last && hasMorePages && !isLoading {
              Task { await loadMoreVideos() }
            }
          }
        }

        // Loading indicator for pagination
        if hasMorePages && !filteredVideos.isEmpty {
          ProgressView()
            .frame(height: 50)
            .gridCellColumns(2)
            .onAppear {
              Task { await loadMoreVideos() }
            }
        }
      }
      .padding()
    }
    .refreshable {
      await refreshVideos()
    }
    .overlay {
      if videos.isEmpty && !isLoading {
        ContentUnavailableView(
          "No Videos Found",
          systemImage: "video.slash",
          description: Text("No VR videos are available in your XBVR library")
        )
      }
    }
  }

  // MARK: - Connection Setup View

  private var connectionSetupView: some View {
    VStack(spacing: 24) {
      Image(systemName: "video.and.waveform")
        .font(.system(size: 60))
        .foregroundColor(.blue)

      VStack(spacing: 12) {
        Text("Connect to XBVR Server")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Enter your XBVR server details to access your VR video library")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Server URL")
            .font(.headline)

          TextField("http://localhost:9998", text: $serverURL)
            .textFieldStyle(.roundedBorder)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("API Key (Optional)")
            .font(.headline)

          SecureField("Enter API key", text: $apiKey)
            .textFieldStyle(.roundedBorder)
        }

        Button("Connect") {
          Task { await connectToXBVR() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(serverURL.isEmpty)
      }
      .frame(maxWidth: 400)

      if let error = error {
        VStack {
          Text("Connection Failed")
            .font(.headline)
            .foregroundColor(.red)

          Text(error.localizedDescription)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .background(.red.opacity(0.1))
        .cornerRadius(12)
      }
    }
    .padding()
  }

  // MARK: - Connection Settings Sheet

  private var connectionSettingsSheet: some View {
    NavigationStack {
      Form {
        Section("Server Configuration") {
          TextField("Server URL", text: $serverURL)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

          SecureField("API Key", text: $apiKey)
        }

        Section("Connection Status") {
          HStack {
            Text("Status")
            Spacer()
            HStack {
              Circle()
                .fill(xbvrService.isConnected ? .green : .red)
                .frame(width: 8, height: 8)

              Text(xbvrService.isConnected ? "Connected" : "Disconnected")
                .foregroundColor(xbvrService.isConnected ? .green : .red)
            }
          }
        }

        Section {
          Button("Test Connection") {
            Task { await testConnection() }
          }
          .disabled(serverURL.isEmpty)

          if xbvrService.isConnected {
            Button("Refresh Library") {
              Task { await refreshVideos() }
            }
          }
        }
      }
      .navigationTitle("XBVR Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            showConnectionSettings = false
          }
        }
      }
    }
  }

  // MARK: - Data Loading Methods

  private func connectToXBVR() async {
    guard !serverURL.isEmpty else { return }

    // Update service configuration
    let config = XBVRService.Configuration(
      baseURL: serverURL,
      apiKey: apiKey.isEmpty ? nil : apiKey
    )

    // Create new service instance with config
    // Note: In a full implementation, you'd update the existing service

    await testConnection()

    if xbvrService.isConnected {
      await loadVideos()
    }
  }

  func testConnection() async {
    do {
      let connected = try await xbvrService.testConnection()
      if connected {
        error = nil
      }
    } catch {
      self.error = error
    }
  }

  private func loadVideos() async {
    guard !isLoading else { return }

    isLoading = true
    currentPage = 1

    do {
      let loadedVideos = try await xbvrService.fetchVideos(
        limit: 20,
        offset: 0,
        sort: "date_added"
      )

      videos = loadedVideos
      hasMorePages = loadedVideos.count >= 20
      error = nil
    } catch {
      self.error = error
    }

    isLoading = false
  }

  private func loadMoreVideos() async {
    guard !isLoading && hasMorePages else { return }

    isLoading = true
    currentPage += 1

    do {
      let moreVideos = try await xbvrService.fetchVideos(
        limit: 20,
        offset: (currentPage - 1) * 20,
        sort: "date_added"
      )

      videos.append(contentsOf: moreVideos)
      hasMorePages = moreVideos.count >= 20
    } catch {
      self.error = error
    }

    isLoading = false
  }

  private func refreshVideos() async {
    videos = []
    await loadVideos()
  }

  private func loadRandomVideo() async {
    do {
      let randomVideos = try await xbvrService.fetchRandomVideos(count: 1)
      if let randomVideo = randomVideos.first {
        selectedVideo = randomVideo
        showingPlayer = true
      }
    } catch {
      self.error = error
    }
  }
}

// MARK: - XBVR Video Card

struct XBVRVideoCard: View {
  let video: XBVRVideo
  let onPlay: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Thumbnail
      ZStack(alignment: .topTrailing) {
        AsyncImage(url: video.thumbnailURL) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay {
              Image(systemName: "video")
                .font(.title)
                .foregroundColor(.gray)
            }
        }
        .frame(height: 180)
        .clipped()

        // Video type badge - visionOS 2.6
        VStack(spacing: 4) {
          Text(video.videoType.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .glassBackgroundEffect()
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .fill(.blue.opacity(0.4))
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))

          Text(video.stereoMode.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .glassBackgroundEffect()
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .fill(.purple.opacity(0.4))
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(8)

        // Play button overlay
        Button(action: onPlay) {
          Image(systemName: "play.circle.fill")
            .font(.system(size: 50))
            .foregroundStyle(.white)
            .background(.black.opacity(0.3))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .position(x: 150, y: 90)  // Center of thumbnail area
      }

      // Video info
      VStack(alignment: .leading, spacing: 8) {
        Text(video.title)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        HStack {
          Text(video.formattedDuration)
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          if let fileSize = video.formattedFileSize {
            Text(fileSize)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        // Tags - visionOS 2.6
        if let tags = video.tags, !tags.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
              ForEach(Array(tags.prefix(3)), id: \.self) { tag in
                Text(tag)
                  .font(.caption2)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(.ultraThinMaterial)
                  .glassBackgroundEffect()
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }

              if tags.count > 3 {
                Text("+\(tags.count - 3)")
                  .font(.caption2)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(.ultraThinMaterial)
                  .glassBackgroundEffect()
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        // Performers
        if let performers = video.performers, !performers.isEmpty {
          Text(performers.joined(separator: ", "))
            .font(.caption)
            .foregroundColor(.blue)
            .lineLimit(1)
        }
      }
      .padding()
    }
    .background(.ultraThinMaterial)
    .glassBackgroundEffect()
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .hoverEffect(.lift)
    .onTapGesture {
      onPlay()
    }
  }
}

// MARK: - Preview

struct XBVRLibraryView_Previews: PreviewProvider {
  static var previews: some View {
    XBVRLibraryView()
  }
}
