// Add these to your existing StashModels.swift file

enum PerformerFilter {
  case all
  case lessThanTwo
  case twoOrMore
  case tenOrMore
}

struct PerformerDetailsResponse: Decodable {
  let data: PerformerData

  struct PerformerData: Decodable {
    let findPerformer: StashScene.Performer
  }
}

// Add SceneFilterType for filtering scenes
struct SceneFilterType: Encodable {
  var tags: [String]?
  var performers: [String]?
  var studios: [String]?
  var searchTerm: String?

  init(
    tags: [String]? = nil, performers: [String]? = nil, studios: [String]? = nil,
    searchTerm: String? = nil
  ) {
    self.tags = tags
    self.performers = performers
    self.studios = studios
    self.searchTerm = searchTerm
  }

  enum CodingKeys: String, CodingKey {
    case tags
    case performers
    case studios
    case searchTerm = "q"
  }
}
