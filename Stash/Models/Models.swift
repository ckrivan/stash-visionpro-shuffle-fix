import Foundation
import SwiftUI

// MARK: - Scene Models
struct StashScene: Codable, Identifiable, Hashable {
  let id: String
  let title: String
  let details: String?
  let url: String?
  let date: String?
  let rating100: Int?
  let organized: Bool?
  let oCounter: Int?
  let paths: ScenePaths
  let files: [SceneFile]?
  let performers: [Performer]?
  let tags: [Tag]?
  let studio: Studio?
  let stashIds: [StashID]?
  let createdAt: String?
  let updatedAt: String?

  struct ScenePaths: Codable, Hashable {
    let screenshot: String?
    let preview: String?
    let stream: String?
    let webp: String?
    let vtt: String?
    let sprite: String?
    let funscript: String?
    let interactive_heatmap: String?
  }

  struct SceneFile: Codable, Hashable {
    let size: Int?
    let duration: Double?
    let video_codec: String?
    let audio_codec: String?
    let width: Int?
    let height: Int?
    let framerate: Double?
    let bitrate: Int?
    let fingerprints: [Fingerprint]?

    var formattedSize: String {
      guard let bytes = size else { return "Unknown" }
      let units = ["B", "KB", "MB", "GB"]
      var level = 0
      var value = Double(bytes)

      while value > 1024 && level < units.count - 1 {
        value /= 1024
        level += 1
      }

      return String(format: "%.1f %@", value, units[level])
    }

    struct Fingerprint: Codable, Hashable {
      let type: String
      let value: String
    }

    // Find oshash fingerprint
    var oshash: String? {
      return fingerprints?.first { $0.type == "oshash" }?.value
    }
  }

  init(
    id: String, title: String, details: String?, url: String?, date: String?, rating100: Int?,
    organized: Bool?, oCounter: Int?, paths: ScenePaths, files: [SceneFile]?,
    performers: [Performer]?, tags: [Tag]?, studio: Studio?, stashIds: [StashID]?,
    createdAt: String?, updatedAt: String?
  ) {
    self.id = id
    self.title = title
    self.details = details
    self.url = url
    self.date = date
    self.rating100 = rating100
    self.organized = organized
    self.oCounter = oCounter
    self.paths = paths
    self.files = files
    self.performers = performers
    self.tags = tags
    self.studio = studio
    self.stashIds = stashIds
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Example Data for Previews
extension StashScene {
  static let example = StashScene(
    id: "1",
    title: "Example Scene",
    details: "Example scene details",
    url: nil,
    date: "2024-12-16",
    rating100: 80,
    organized: true,
    oCounter: 1,
    paths: ScenePaths(
      screenshot: "https://example.com/screenshot.jpg",
      preview: "https://example.com/preview.mp4",
      stream: "https://example.com/stream.m3u8",
      webp: nil,
      vtt: nil,
      sprite: nil,
      funscript: nil,
      interactive_heatmap: nil
    ),
    files: [
      SceneFile(
        size: 1_000_000,
        duration: 300,
        video_codec: "h264",
        audio_codec: "aac",
        width: 1920,
        height: 1080,
        framerate: 60,
        bitrate: 10000,
        fingerprints: [
          SceneFile.Fingerprint(type: "oshash", value: "example_oshash")
        ]
      )
    ],
    performers: [Performer.example],
    tags: [Tag.example],
    studio: nil,
    stashIds: nil,
    createdAt: "2024-12-16T00:00:00Z",
    updatedAt: "2024-12-16T00:00:00Z"
  )
}

// MARK: - Performer Models
extension StashScene {
  struct Performer: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let gender: String?
    let url: String?
    let twitter: String?
    let instagram: String?
    let image_path: String?
    let scene_count: Int?
    let image_count: Int?
    let gallery_count: Int?
    let rating100: Int?
    let favorite: Bool?
    let country: String?
    let height_cm: Int?
    let fake_tits: String?
    let career_length: String?
    let tattoos: String?
    let piercings: String?
    let aliases: [String]?
    let tags: [Tag]?
    let stash_ids: [StashID]?
    let created_at: String?
    let updated_at: String?
    let details: String?
  }
}

// MARK: - Example Data for Previews
extension StashScene.Performer {
  static let example = StashScene.Performer(
    id: "1",
    name: "Example Performer",
    gender: "Female",
    url: nil,
    twitter: nil,
    instagram: nil,
    image_path: nil,
    scene_count: 5,
    image_count: 10,
    gallery_count: 2,
    rating100: 80,
    favorite: true,
    country: "US",
    height_cm: 170,
    fake_tits: nil,
    career_length: nil,
    tattoos: nil,
    piercings: nil,
    aliases: nil,
    tags: nil,
    stash_ids: nil,
    created_at: "2024-12-16",
    updated_at: "2024-12-16",
    details: "Example performer details"
  )
}

// MARK: - Tag Models
extension StashScene {
  struct Tag: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let scene_count: Int?
    let image_count: Int?
  }
}

// MARK: - Example Data for Previews
extension StashScene.Tag {
  static let example = StashScene.Tag(
    id: "1",
    name: "Example Tag",
    scene_count: 5,
    image_count: 10
  )
}

// MARK: - Studio Models
extension StashScene {
  struct Studio: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String?
    let image_path: String?
  }
}

// MARK: - StashID Models
extension StashScene {
  struct StashID: Codable, Hashable {
    let endpoint: String
    let stash_id: String
  }
}

// MARK: - Scene Marker Models
struct SceneMarker: Codable, Identifiable, Hashable {
  struct MarkerScene: Codable, Hashable {
    let id: String
    let title: String
    let files: [FileInfo]?
    let performers: [PerformerInfo]?

    struct FileInfo: Codable, Hashable {
      let width: Int?
      let height: Int?
      let path: String?
    }

    struct PerformerInfo: Codable, Hashable {
      let id: String
      let name: String
      let image_path: String?
    }
  }

  let id: String
  let title: String
  let seconds: Double
  let end_seconds: Double?
  let stream: String
  let preview: String
  let screenshot: String
  let scene: MarkerScene?
  let primary_tag: StashScene.Tag?
  let tags: [StashScene.Tag]?

  var formattedTime: String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }

  var formattedDuration: String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }
}

// MARK: - Example Data for Previews
extension SceneMarker {
  static let example = SceneMarker(
    id: "1",
    title: "Example Marker",
    seconds: 60,
    end_seconds: 70,
    stream: "https://example.com/marker.mp4",
    preview: "https://example.com/preview.jpg",
    screenshot: "https://example.com/screenshot.jpg",
    scene: MarkerScene(
      id: "1",
      title: "Example Scene",
      files: [MarkerScene.FileInfo(width: 1920, height: 1080, path: "/path/to/video")],
      performers: [
        MarkerScene.PerformerInfo(id: "1", name: "Example Performer", image_path: "/path/to/image")
      ]
    ),
    primary_tag: StashScene.Tag.example,
    tags: [StashScene.Tag.example]
  )
}

// MARK: - API Response Models
struct GraphQLResponse<T: Decodable>: Decodable {
  let data: T
  let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
  let message: String
  let locations: [GraphQLErrorLocation]?
  let path: [String]?
}

struct GraphQLErrorLocation: Decodable {
  let line: Int
  let column: Int
}

struct SceneResponse: Decodable {
  let findScene: StashScene
}

struct ScenesResponse: Decodable {
  struct DataResponse: Decodable {
    struct FindScenesResult: Decodable {
      let count: Int
      let scenes: [StashScene]
    }
    let findScenes: FindScenesResult
  }
  let data: DataResponse
}

struct PerformersResponse: Decodable {
  struct DataResponse: Decodable {
    struct FindPerformersResult: Decodable {
      let count: Int
      let performers: [StashScene.Performer]
    }
    let findPerformers: FindPerformersResult
  }
  let data: DataResponse
}

struct SceneMarkersResponse: Decodable {
  struct DataResponse: Decodable {
    struct FindSceneMarkersResult: Decodable {
      let count: Int
      let scene_markers: [SceneMarker]
    }
    let findSceneMarkers: FindSceneMarkersResult
  }
  let data: DataResponse
}

// Note: Example and formattedTime are already defined elsewhere in this file

struct TagSearchResponse: Decodable {
  struct DataResponse: Decodable {
    struct FindTagsResult: Decodable {
      let count: Int
      let tags: [StashScene.Tag]
    }
    let findTags: FindTagsResult
  }
  let data: DataResponse
}

struct TagCreateResponse: Decodable {
  struct DataResponse: Decodable {
    let tagCreate: StashScene.Tag
  }
  let data: DataResponse
}

struct SceneUpdateResponse: Decodable {
  struct DataResponse: Decodable {
    let sceneUpdate: StashScene
  }
  let data: DataResponse
}
