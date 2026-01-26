import Foundation

// Connection parameters
let serverAddress = "http://192.168.86.100:9999"
let apiKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo"

// GraphQL query to get performers
let query = """
  {
      "operationName": "FindPerformers",
      "variables": {
          "filter": {
              "page": 1,
              "per_page": 10,
              "sort": "name",
              "direction": "ASC"
          }
      },
      "query": "query FindPerformers($filter: FindFilterType) { findPerformers(filter: $filter) { count performers { id name gender birthdate country image_path scene_count } } }"
  }
  """

// Create the request
guard let url = URL(string: "\(serverAddress)/graphql") else {
  print("Invalid URL")
  exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
request.httpBody = query.data(using: .utf8)

// Create the task and wait group
let session = URLSession.shared
let semaphore = DispatchSemaphore(value: 0)

// Execute the request
print("Fetching performers from Stash at \(serverAddress)...")
let task = session.dataTask(with: request) { data, response, error in
  defer { semaphore.signal() }

  if let error = error {
    print("❌ Error: \(error.localizedDescription)")
    return
  }

  guard let httpResponse = response as? HTTPURLResponse else {
    print("❌ No HTTP response")
    return
  }

  print("📝 HTTP Status: \(httpResponse.statusCode)")

  guard let data = data else {
    print("❌ No data received")
    return
  }

  // Try to pretty print the JSON for better readability
  if let jsonObject = try? JSONSerialization.jsonObject(with: data),
    let prettyData = try? JSONSerialization.data(
      withJSONObject: jsonObject, options: .prettyPrinted),
    let prettyString = String(data: prettyData, encoding: .utf8) {
    print("📥 Response:")
    print(prettyString)

    // Parse the JSON to display performer count
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataObj = json["data"] as? [String: Any],
      let findPerformers = dataObj["findPerformers"] as? [String: Any],
      let count = findPerformers["count"] as? Int,
      let performers = findPerformers["performers"] as? [[String: Any]] {
      print("\n✅ Found \(count) total performers")
      print("📋 Showing first \(performers.count) performers:")

      for (index, performer) in performers.enumerated() {
        let name = performer["name"] as? String ?? "Unknown"
        let sceneCount = performer["scene_count"] as? Int ?? 0
        print("\(index + 1). \(name) - \(sceneCount) scenes")
      }
    }
  } else if let jsonString = String(data: data, encoding: .utf8) {
    print("📥 Response: \(jsonString)")
  }
}

task.resume()
semaphore.wait()
