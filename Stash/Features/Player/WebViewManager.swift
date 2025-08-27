import SwiftUI
import WebKit

class WebViewManager: ObservableObject {
  @Published var isLoading = true
  @Published var error: Error?
  @Published var currentTime: Double = 0
  @Published var duration: Double = 0
  @Published var isPlaying = false

  private var webView: WKWebView?
  private var timeObserver: Any?

  func setWebView(_ webView: WKWebView) {
    self.webView = webView
  }

  func play() {
    webView?.evaluateJavaScript("window.player.play()")
    isPlaying = true
  }

  func pause() {
    webView?.evaluateJavaScript("window.player.pause()")
    isPlaying = false
  }

  func seek(to time: Double) {
    webView?.evaluateJavaScript("window.player.seekTo(\(time))")
  }

  func cleanup() {
    if let timeObserver = timeObserver {
      NotificationCenter.default.removeObserver(timeObserver)
    }
    webView = nil
    isPlaying = false
    currentTime = 0
    duration = 0
  }
}
