import AVKit
import Combine
import SwiftUI
import WebKit

// MARK: - Fixed Video Player Implementation for Vision Pro
// This version resolves issues with:
// 1. Aspect ratio distortion when resizing
// 2. Disappearing scrubber controls

// Notification name extension for video player
extension Notification.Name {
  static let videoPlayerShouldSwitch = Notification.Name("videoPlayerShouldSwitch")
}

// MARK: - Basic WebView for Video
class VideoWebView: WKWebView {
  // Constants for time skipping
  let rewindTime: Double = 10.0
  let forwardTime: Double = 30.0
  private var timeSkipObserver: NSObjectProtocol?
  private var playAttemptTimer: Timer?
  private var playAttemptCount = 0
  private let maxPlayAttempts = 10

  override init(frame: CGRect, configuration: WKWebViewConfiguration) {
    super.init(frame: frame, configuration: configuration)
    setupTimeSkipObserver()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupTimeSkipObserver()
  }

  deinit {
    if let observer = timeSkipObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    stopPlayAttemptTimer()
  }

  private func setupTimeSkipObserver() {
    // Listen for time skip requests
    timeSkipObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name("TimeSkipRequest"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self else { return }

      if let seconds = notification.userInfo?["seconds"] as? Double {
        // Check if this is a webView with a valid player before processing the seek
        self.evaluateJavaScript("document.getElementById('player') != null") { result, error in
          if let hasPlayer = result as? Bool, hasPlayer {
            DispatchQueue.main.async {
              // Use main thread for UI operations
              self.skipTime(seconds)
            }
          } else if let error = error {
            print("⚠️ Error checking for player: \(error)")
          }
        }
      }
    }

    // Listen for force play requests
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("forcePlayRequest"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }

      // First try to play using our enhanced script
      self.aggressivePlay()

      // Start a timer for repeated play attempts
      self.startPlayAttemptTimer()
    }

    // Listen for JavaScript execution requests (used for showing controls and other direct JS)
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("executeJavaScript"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self else { return }

      if let script = notification.userInfo?["script"] as? String {
        print("⚙️ Executing custom JavaScript")
        self.evaluateJavaScript(script) { result, error in
          if let error = error {
            print("⚠️ Error executing JavaScript: \(error)")
          } else if let success = result as? Bool, success {
            print("✓ JavaScript executed successfully")
          }
        }
      }
    }
  }

  private func aggressivePlay() {
    // Force the player to play with an enhanced script that makes multiple attempts
    self.evaluateJavaScript(
      """
      (function() {
          var video = document.getElementById('player');
          if (!video) return false;
          
          console.log('Force playing video - attempt \(playAttemptCount + 1)');
          
          // First check if already playing
          if (!video.paused) {
              console.log('Video is already playing, no action needed');
              
              // Even if playing, check if visually frozen by checking if time is advancing
              if (window.lastTimeCheck === video.currentTime && video.currentTime > 0) {
                  console.log('Video appears stuck visually - applying visual kickstart');
                  
                  // Try a visual kickstart with playbackRate change
                  try {
                      var originalRate = video.playbackRate;
                      // Briefly speed up playback to force frame updates
                      video.playbackRate = 1.2;
                      
                      setTimeout(function() {
                          video.playbackRate = originalRate;
                      }, 150);
                      
                      // Also do a tiny seek forward to force a frame update
                      video.currentTime += 0.1;
                  } catch(e) {
                      console.log('Visual kickstart error:', e);
                  }
              }
              
              // Save current time to detect freezes on next check
              window.lastTimeCheck = video.currentTime;
              
              // Make sure to detect aspect ratio even if already playing
              setTimeout(function() {
                  var aspectRatio = video.videoWidth / video.videoHeight;
                  console.log("Aspect ratio check during play: " + aspectRatio.toFixed(2));
              }, 1000);
              
              return true;
          }
          
          // Perform several user-gesture-like actions that might help autoplay
          video.controls = true;
          
          // Explicitly force playing state regardless of current state
          video.paused = false;
          
          // Reset any user paused flags to ensure automatic resume works
          window.userPaused = false;
          
          // Try visual kickstart with playbackRate to force frame rendering
          try {
              // Save original rate to restore
              var originalRate = video.playbackRate || 1.0;
              // Briefly change rate to force rendering pipeline
              video.playbackRate = 1.1;
              
              setTimeout(function() {
                  video.playbackRate = originalRate;
              }, 100);
          } catch(e) {
              console.log('Rate adjustment error:', e);
          }
          
          // First attempt - immediate play
          var playPromise = video.play();
          
          if (playPromise !== undefined) {
              playPromise.catch(e1 => {
                  console.error('Initial play attempt failed:', e1);
                  
                  // Try again with small delay
                  setTimeout(function() {
                      console.log('Second attempt after delay');
                      
                      // Try again but with different approach
                      video.play().catch(e2 => {
                          console.error('Second play attempt failed:', e2);
                          
                          // Final desperate attempt
                          setTimeout(function() {
                              console.log('Final play attempt with more aggressive approach');
                              // Try setting currentTime which sometimes triggers play on iOS
                              if (video.currentTime === 0) {
                                  video.currentTime = 0.1;
                              } else {
                                  video.currentTime = video.currentTime - 0.1;
                              }
                              
                              // Only mute as a last resort if previous attempts failed
                              if (video.paused) {
                                  console.log('Trying play with mute as last resort');
                                  video.muted = true;
                              }
                              
                              // Force play state and use the play() method
                              video.paused = false;
                              video.play();
                              
                              // Check status after slight delay and force play again if still paused
                              setTimeout(function() {
                                  if (video.paused) {
                                      console.log('Video still paused after all attempts, forcing play again');
                                      video.paused = false;
                                      video.play();
                                  } else {
                                      console.log('Success! Video is now playing');
                                      
                                      // Save time for freeze detection
                                      window.lastTimeCheck = video.currentTime;
                                      
                                      // Set up a quick check to verify video is actually progressing
                                      setTimeout(function() {
                                          if (window.lastTimeCheck === video.currentTime && !video.paused) {
                                              console.log('Video appears frozen - applying visual kickstart');
                                              // Try a slight seek to kickstart rendering
                                              video.currentTime += 0.1;
                                          }
                                      }, 500);
                                  }
                              }, 500);
                              
                          }, 200);
                      });
                  }, 200);
              });
          }
          
          return true;
      })();
      """
    ) { [weak self] _, _ in
      guard let self = self else { return }

      // Check if the video actually started playing
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.checkPlaybackStatus()
      }
    }
  }

  private func checkPlaybackStatus() {
    self.evaluateJavaScript("!document.getElementById('player')?.paused") {
      [weak self] result, _ in
      guard let self = self else { return }

      if let isPlaying = result as? Bool, isPlaying {
        print("✅ Video is confirmed playing")
        self.stopPlayAttemptTimer()
      } else {
        print("⚠️ Video still not playing, will continue attempts")
      }
    }
  }

  private func startPlayAttemptTimer() {
    stopPlayAttemptTimer()
    playAttemptCount = 0

    playAttemptTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
      [weak self] timer in
      guard let self = self else {
        timer.invalidate()
        return
      }

      self.playAttemptCount += 1
      if self.playAttemptCount >= self.maxPlayAttempts {
        print("⚠️ Reached maximum play attempts, giving up")
        self.stopPlayAttemptTimer()
        return
      }

      print("🔄 Play attempt \(self.playAttemptCount) of \(self.maxPlayAttempts)")
      self.aggressivePlay()
    }
  }

  private func stopPlayAttemptTimer() {
    playAttemptTimer?.invalidate()
    playAttemptTimer = nil
    playAttemptCount = 0
  }

  // Method to skip time
  func skipTime(_ seconds: Double) {
    // JavaScript to update video time with safety checks
    let script = """
      (function() {
          console.log('Attempting time skip: \(seconds) seconds');
          try {
              var video = document.getElementById('player');
              if (!video) {
                  console.error('Player element not found for time skip');
                  return false;
              }
              
              // Ensure we have a valid duration
              if (!video.duration || isNaN(video.duration)) {
                  console.error('Invalid duration for time skip');
                  return false;
              }
              
              // Calculate new time with boundary checks
              var currentTime = video.currentTime || 0;
              var newTime = currentTime + \(seconds);
              
              // Boundary check (stay within valid range)
              newTime = Math.max(0, Math.min(newTime, video.duration));
              
              console.log('Skipping from ' + currentTime.toFixed(2) + ' to ' + newTime.toFixed(2));
              
              // Apply the new time
              video.currentTime = newTime;
              
              // Force controls visible after seeking
              video.controls = true;
              
              // Dispatch events to make controls visible
              video.dispatchEvent(new MouseEvent('mousemove', {
                  bubbles: true,
                  cancelable: true
              }));
              
              // Also ensure controls stay visible by forcing them
              forceControlsVisibility();
              
              // Successful skip
              return true;
          } catch (error) {
              console.error('Error during time skip:', error);
              return false;
          }
      })();
      """

    evaluateJavaScript(script) { result, error in
      if let error = error {
        print("⚠️ Error during time skip: \(error)")
      } else if let success = result as? Bool, success {
        print("✅ Time skip successful: \(seconds) seconds")
      } else {
        print("⚠️ Time skip failed")
      }
    }
  }
}

// MARK: - Web Video Player Implementation
struct WebVideoPlayerView: UIViewRepresentable {
  var scene: StashScene
  @EnvironmentObject var appModel: AppModel
  @StateObject private var webViewManager = WebViewManager()
  @Binding var isLoading: Bool
  let onLoadingStateChanged: (Bool) -> Void
  let onVideoFinish: () -> Void

  func makeUIView(context: Context) -> WKWebView {
    print("🎮 Creating web video player for scene: \(scene.id)")

    // Configure WKWebViewConfiguration
    let config = WKWebViewConfiguration()

    // Enable inline playback
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    // Optional: Add script for better mobile video handling
    let userScript = WKUserScript(
      source: """
        document.addEventListener('DOMContentLoaded', function() {
            // Force playback settings
            document.querySelector('video')?.setAttribute('playsinline', '');
            document.querySelector('video')?.setAttribute('webkit-playsinline', '');
            
            // Prevent auto-sleep during video playback
            document.querySelector('video')?.addEventListener('play', function() {
                try { navigator.wakeLock.request('screen'); } catch(e) { console.log('WakeLock API not supported'); }
            });
        });
        """,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )
    config.userContentController.addUserScript(userScript)

    // Create WebView with our custom subclass
    let webView = VideoWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.allowsBackForwardNavigationGestures = false
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.scrollView.pinchGestureRecognizer?.isEnabled = false

    if #available(iOS 16.4, *) {
      webView.isInspectable = true
    }

    // Get stream URL with API key
    let api = StashAPI()
    let streamURL = "\(api.serverAddress)/scene/\(scene.id)/stream?apikey=\(api.apiKey)"
    // HLS fallback URL
    let hlsURL =
      "\(api.serverAddress)/scene/\(scene.id)/stream.m3u8?resolution=ORIGINAL&apikey=\(api.apiKey)"

    // Get time parameter for direct jumping to a specific time
    var timeParam = ""
    if let startTime = context.coordinator.startTime, startTime > 0 {
      timeParam = "#t=\(Int(startTime))"
      print("🎮 Adding time parameter to HTML5 video: \(timeParam) (\(startTime) seconds)")
    }

    let html = """
      <!DOCTYPE html>
      <html>
      <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
              body { 
                  margin: 0; 
                  padding: 0; 
                  width: 100%; 
                  height: 100%; 
                  background-color: #000; 
                  overflow: hidden;
              }
              video { 
                  width: 100%;
                  height: 100%;
                  object-fit: contain;
              }
          </style>
      </head>
      <body>
          <video id="player" src="\(streamURL)\(timeParam)" controls playsinline>
              <source src="\(hlsURL)" type="application/x-mpegURL">
              Your browser does not support the video tag.
          </video>
          <script>
              const video = document.getElementById('player');
              
              video.addEventListener('play', () => {
                  window.webkit.messageHandlers.videoStarted.postMessage({});
              });
              
              video.addEventListener('ended', () => {
                  window.webkit.messageHandlers.videoFinished.postMessage({});
              });
              
              video.addEventListener('error', (e) => {
                  window.webkit.messageHandlers.videoError.postMessage({
                      error: e.target.error.message
                  });
              });
              
              window.player = {
                  play: () => video.play(),
                  pause: () => video.pause(),
                  seekTo: (seconds) => { video.currentTime = seconds; },
                  getCurrentTime: () => video.currentTime,
                  getDuration: () => video.duration
              };
          </script>
      </body>
      </html>
      """

    webView.loadHTMLString(html, baseURL: URL(string: api.serverAddress))
    webViewManager.setWebView(webView)

    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    // Updates handled by coordinator
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  // MARK: - Coordinator
  class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var parent: WebVideoPlayerView
    var startTime: Double?

    init(_ parent: WebVideoPlayerView) {
      self.parent = parent
      super.init()
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.isLoading = false
      parent.onLoadingStateChanged(false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.isLoading = false
      parent.onLoadingStateChanged(false)
      print("🚫 Web video player navigation error: \(error.localizedDescription)")
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      switch message.name {
      case "videoStarted":
        print("🎬 Video playback started")
      case "videoFinished":
        parent.onVideoFinish()
      case "videoError":
        if let dict = message.body as? [String: Any],
          let errorMessage = dict["error"] as? String {
          print("🚫 Video error: \(errorMessage)")
        }
      default:
        break
      }
    }

    // MARK: - WKUIDelegate
    func webView(
      _ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
      completionHandler(.performDefaultHandling, nil)
    }
  }
}
