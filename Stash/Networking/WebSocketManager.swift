import Foundation

class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
  private var webSocket: URLSessionWebSocketTask?
  private let serverURL: URL
  private let apiKey: String

  init(serverURL: URL, apiKey: String) {
    self.serverURL = serverURL
    self.apiKey = apiKey
    super.init()
    setupWebSocket()
  }

  private func setupWebSocket() {
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    var request = URLRequest(url: serverURL)
    request.setValue("graphql-transport-ws", forHTTPHeaderField: "Sec-WebSocket-Protocol")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    webSocket = session.webSocketTask(with: request)
    webSocket?.resume()

    // Send connection init message with explicit types
    let payload: [String: String] = ["Authorization": "Bearer \(apiKey)"]
    let initMessage: [String: Any] = [
      "type": "connection_init" as String,
      "payload": payload
    ]

    if let data = try? JSONSerialization.data(withJSONObject: initMessage) {
      webSocket?.send(.data(data)) { error in
        if let error = error {
          print("❌ WebSocket connection init error: \(error)")
        } else {
          print("✅ WebSocket connection initialized")
        }
      }
    }

    receiveMessage()
  }

  private func receiveMessage() {
    webSocket?.receive { [weak self] result in
      switch result {
      case .success(let message):
        switch message {
        case .string(let text):
          print("📥 Received message: \(text)")
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            print("📥 Received data: \(text)")
          }
        @unknown default:
          break
        }

        // Continue receiving messages
        self?.receiveMessage()

      case .failure(let error):
        print("❌ WebSocket receive error: \(error)")
        // Try to reconnect after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
          self?.setupWebSocket()
        }
      }
    }
  }

  func subscribe(to subscription: String) {
    let message: [String: Any] = [
      "type": "subscribe",
      "id": UUID().uuidString,
      "payload": [
        "query": subscription
      ]
    ]

    if let data = try? JSONSerialization.data(withJSONObject: message) {
      webSocket?.send(.data(data)) { error in
        if let error = error {
          print("❌ WebSocket subscription error: \(error)")
        } else {
          print("✅ WebSocket subscription sent")
        }
      }
    }
  }

  func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    print("✅ WebSocket connected")
  }

  func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
  ) {
    print("❌ WebSocket closed with code: \(closeCode)")
    if let reason = reason, let text = String(data: reason, encoding: .utf8) {
      print("Reason: \(text)")
    }

    // Try to reconnect after a delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      self.setupWebSocket()
    }
  }

  deinit {
    webSocket?.cancel()
  }
}
