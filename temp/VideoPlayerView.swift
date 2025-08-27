import AVKit
import Combine
import SwiftUI
import WebKit

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
              
              // Make sure to detect aspect ratio even if already playing
              setTimeout(function() {
                  var aspectRatio = video.videoWidth / video.videoHeight;
                  console.log("Aspect ratio check during play: " + aspectRatio.toFixed(2));
              }, 1000);
              
              return true;
          }
          
          // Perform several user-gesture-like actions that might help autoplay
          video.controls = true;
          
          // Don't auto-mute for better user experience
          // Only mute if playback fails after initial attempt
          
          // First attempt - immediate play
          var playPromise = video.play();
          if (playPromise !== undefined) {
              playPromise.catch(e => {
                  console.error('Force play error:', e);
                  
                  // Second attempt - using timeout and interaction simulation
                  setTimeout(function() {
                      console.log('Second play attempt with interaction simulation');
                      
                      // Click simulation (won't actually work for autoplay policies, but worth trying)
                      try {
                          video.dispatchEvent(new MouseEvent('click', {
                              view: window,
                              bubbles: true,
                              cancelable: true
                          }));
                      } catch (e) { 
                          console.log('Click simulation error', e);
                      }
                      
                      // Touch simulation
                      try {
                          video.dispatchEvent(new TouchEvent('touchstart', {
                              bubbles: true,
                              cancelable: true,
                              view: window
                          }));
                      } catch (e) {
                          console.log('Touch simulation error', e);
                      }
                      
                      // Try play again
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
                              
                              video.play();
                              
                              // Check status after slight delay
                              setTimeout(function() {
                                  if (video.paused) {
                                      console.log('Video still paused after all attempts');
                                  } else {
                                      console.log('Success! Video is now playing');
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
              
              // Calculate new time with bounds checking
              var currentTime = video.currentTime || 0;
              var newTime = Math.max(0, Math.min(video.duration, currentTime + \(seconds)));
              
              // Log the skip operation
              console.log('Skipping from ' + currentTime + ' to ' + newTime);
              
              // First pause to improve seek reliability
              video.pause();
              
              // Update current time
              video.currentTime = newTime;
              
              // Resume playback after a short delay
              setTimeout(function() {
                  video.play().catch(err => console.error('Error resuming after skip:', err));
              }, 100);
              
              // Skip showing time feedback from this function, we'll handle it in Swift instead
              // This prevents duplicate feedback (one from web, one from Swift)
              // Continue with the rest of the skip functionality
              
              return true;
          } catch (err) {
              console.error('Error during time skip:', err);
              return false;
          }
      })();
      """

    evaluateJavaScript(script) { result, error in
      if let error = error {
        print("⚠️ Error adjusting video time: \(error)")

        // Try a simple fallback if the complex approach fails
        let fallbackScript =
          "var video=document.getElementById('player'); if(video){video.currentTime=Math.max(0,Math.min(video.duration,(video.currentTime+\(seconds)))); return true;} return false;"
        self.evaluateJavaScript(fallbackScript, completionHandler: nil)
      } else if let success = result as? Bool, success {
        let action = seconds < 0 ? "Rewinding" : "Fast-forwarding"
        let time = abs(seconds)
        print("⏱️ \(action) \(time) seconds")
      } else {
        print("❌ Failed to skip time")
      }
    }
  }

  private func showTimeSkipFeedback(_ seconds: Double) {
    // Create a feedback indicator to show the time skip
    let direction = seconds < 0 ? "◀◀" : "▶▶"
    let text = "\(direction) \(abs(Int(seconds)))s"

    // Use JavaScript to show a temporary overlay with the skip info
    let script = """
      (function() {
          var feedback = document.getElementById('timeSkipFeedback');
          if (!feedback) {
              feedback = document.createElement('div');
              feedback.id = 'timeSkipFeedback';
              feedback.style.position = 'absolute';
              feedback.style.top = '20%';
              feedback.style.left = '50%';
              feedback.style.transform = 'translate(-50%, -50%)';
              feedback.style.backgroundColor = 'rgba(0,0,0,0.7)';
              feedback.style.color = 'white';
              feedback.style.padding = '20px 40px';
              feedback.style.borderRadius = '15px';
              feedback.style.fontSize = '40px';
              feedback.style.fontWeight = 'bold';
              feedback.style.zIndex = '9999';
              document.body.appendChild(feedback);
          }
          
          // Set content and show
          feedback.innerText = '\(text)';
          feedback.style.opacity = '1';
          
          // Clear any existing timeouts
          if (window.feedbackTimeout) {
              clearTimeout(window.feedbackTimeout);
          }
          
          // Hide after 1 second
          window.feedbackTimeout = setTimeout(function() {
              feedback.style.opacity = '0';
          }, 1000);
          
          return true;
      })();
      """

    evaluateJavaScript(script) { _, error in
      if let error = error {
        print("⚠️ Error showing feedback: \(error)")
      }
    }
  }
}

// MARK: - Web Video Player
struct WebVideoPlayerView: UIViewRepresentable {
  @EnvironmentObject var appModel: AppModel
  let scene: StashScene
  let onLoadingStateChanged: (Bool) -> Void
  let onDismiss: (() -> Void)?

  func makeUIView(context: Context) -> VideoWebView {
    // Create web view configuration
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []

    // Create basic video web view
    let webView = VideoWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator

    // Load video page with direct URL
    let api = context.coordinator.appModel.api
    let streamURL = "\(api.serverAddress)/scene/\(scene.id)/stream?apikey=\(api.apiKey)"
    // HLS fallback URL
    let hlsURL =
      "\(api.serverAddress)/scene/\(scene.id)/stream.m3u8?resolution=ORIGINAL&apikey=\(api.apiKey)"

    // Get time parameter for direct jumping to a specific time
    var timeParam = ""
    if let startTime = context.coordinator.getStartTime(), startTime > 0 {
      // Use the t parameter format for HTML5 video, but ensure it's properly formatted
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
                  font-family: -apple-system, "SF Pro Text", "SF Pro", "San Francisco", system-ui, sans-serif;
              }
              /* Base video styling */
              video { 
                  width: 100%;
                  height: 100%;
                  object-fit: contain;
                  position: relative;
                  background-color: black;
                  transition: all 0.25s ease-out;
              }
              
              /* Add special class for 4:3 mode */
              .video-4-3 {
                  width: auto !important;
                  height: 45% !important;
                  max-width: 75% !important;
                  margin: 0 auto !important;
                  display: block !important;
                  margin-bottom: 40% !important;  /* Pull up to show controls better */
              }
              
              /* Ultra-widescreen (2.35:1 and above) */
              .video-ultrawide {
                  width: 100% !important;
                  height: auto !important;
                  max-height: 70% !important;
                  margin: 0 auto !important;
                  display: block !important;
                  margin-bottom: 15% !important;
              }
              
              /* 2:1 widescreen format */
              .video-21 {
                  width: 100% !important;
                  height: auto !important;
                  max-height: 80% !important;
                  margin: 0 auto !important;
                  display: block !important;
                  margin-bottom: 10% !important;
              }
              /* Make playhead and controls MUCH larger for VisionPro */
              video::-webkit-media-controls-timeline {
                  transform: scale(1.2);
                  transform-origin: center center;
                  margin: 10px 0;
                  height: 20px !important;
                  position: relative;
                  left: 0;
                  width: 96% !important;
              }
              
              video::-webkit-media-controls-play-button,
              video::-webkit-media-controls-volume-slider,
              video::-webkit-media-controls-mute-button {
                  transform: scale(1.6);
                  margin: 8px;
              }
              
              video::-webkit-media-controls-panel {
                  padding: 12px 0;
                  background: rgba(0,0,0,0.8);
                  height: auto !important;
                  display: flex !important;
                  justify-content: center !important;
                  align-items: center !important;
              }
              
              /* When in 4:3 mode, make controls more prominent */
              .video-4-3::-webkit-media-controls-panel {
                  padding: 25px 0 !important;
                  background: rgba(0,0,0,0.95) !important;
                  margin-top: 15px !important;
                  border-top: 3px solid rgba(255,255,255,0.2) !important;
                  border-radius: 10px 10px 0 0 !important;
                  box-shadow: 0 -5px 15px rgba(0,0,0,0.5) !important;
              }
              
              /* When in 4:3 mode, position controls closer to video */
              .video-4-3::-webkit-media-controls {
                  bottom: -30px !important;
              }
              
              /* Ensure playhead is extra visible in 4:3 mode */
              .video-4-3::-webkit-media-controls-timeline {
                  transform: scale(1.3) !important;
                  height: 24px !important;
                  margin: 12px 0 !important;
              }
              
              /* Enhanced visibility for playhead */
              video::-webkit-media-controls {
                  opacity: 1 !important;
                  visibility: visible !important;
                  display: flex !important;
                  width: 100% !important;
                  position: absolute !important;
                  bottom: 0 !important;
                  background: linear-gradient(to top, rgba(0,0,0,0.8), rgba(0,0,0,0)) !important;
              }
              
              /* Add extra shadow area below 4:3 videos for better control visibility */
              .video-4-3::after {
                  content: "";
                  position: absolute;
                  bottom: -60px;
                  left: 0;
                  right: 0;
                  height: 150px;
                  background: linear-gradient(to bottom, rgba(0,0,0,0.95), rgba(0,0,0,0.7)) !important;
                  z-index: -1;
              }
              
              /* Make the scrubber track more visible */
              video::-webkit-media-controls-timeline::-webkit-slider-runnable-track {
                  height: 10px !important;
                  background-color: rgba(255,255,255,0.3) !important;
                  border-radius: 5px !important;
              }
              
              /* Make the scrubber track extra visible in 4:3 mode */
              .video-4-3::-webkit-media-controls-timeline::-webkit-slider-runnable-track {
                  height: 12px !important;
                  background-color: rgba(255,255,255,0.4) !important;
                  border-radius: 6px !important;
                  border: 1px solid rgba(255,255,255,0.2) !important;
              }
              
              /* Make the scrubber handle much larger and more visible */
              video::-webkit-media-controls-timeline::-webkit-slider-thumb {
                  width: 24px !important;
                  height: 24px !important;
                  border-radius: 12px !important;
                  background: white !important;
                  border: 2px solid #0a84ff !important;
                  box-shadow: 0 0 10px rgba(10, 132, 255, 0.8) !important;
                  position: relative !important;
                  top: -3px !important;
              }
              
              /* Make the scrubber thumb extra large in 4:3 mode */
              .video-4-3::-webkit-media-controls-timeline::-webkit-slider-thumb {
                  width: 28px !important;
                  height: 28px !important;
                  border-radius: 14px !important;
                  border: 3px solid #0a84ff !important;
                  box-shadow: 0 0 15px rgba(10, 132, 255, 0.9) !important;
                  top: -5px !important;
              }
              
              /* Make progress indicator more visible */
              video::-webkit-media-controls-timeline::-webkit-progress-value {
                  background-color: #0a84ff !important;
                  border-radius: 5px !important;
              }
              
              /* Make progress indicator extra prominent in 4:3 mode */
              .video-4-3::-webkit-media-controls-timeline::-webkit-progress-value {
                  background-color: #2196f3 !important;
                  border-radius: 5px !important;
                  height: 12px !important;
                  box-shadow: 0 0 8px rgba(33, 150, 243, 0.6) !important;
              }
              .controls { 
                  position: absolute; 
                  bottom: 20px; 
                  left: 0; right: 0; 
                  display: flex; 
                  justify-content: center; 
              }
              button { 
                  background: rgba(0,0,0,0.5); 
                  color: white; 
                  border: none; 
                  padding: 10px 20px; 
                  margin: 0 5px; 
                  border-radius: 5px; 
              }
              .loading { 
                  position: absolute; 
                  top: 50%; 
                  left: 50%; 
                  transform: translate(-50%, -50%); 
                  color: white; 
                  font-size: 24px;
                  font-family: -apple-system, "SF Pro Text", "SF Pro", "San Francisco", system-ui, sans-serif;
                  font-weight: 500;
              }
          </style>
      </head>
      <body>
          <div id="loading" class="loading">Loading video...</div>
          <video id="player" controls autoplay playsinline src="\(streamURL)\(timeParam)">
          </video>
          
          <!-- Fit mode button with SF Symbols style -->
          <div style="
              position: absolute;
              top: 80px;
              right: 20px;
              z-index: 9999;
          " id="fitModeButton">
              <button id="fitButton" style="
                  background: rgba(0,0,0,0.5);
                  border: 1px solid rgba(255,255,255,0.2);
                  color: white;
                  font-size: 16px;
                  width: 44px;
                  height: 44px;
                  border-radius: 22px;
                  cursor: pointer;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  backdrop-filter: blur(20px);
                  -webkit-backdrop-filter: blur(20px);
                  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
              ">
                  <svg id="fitModeIcon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                      <polyline points="9,3 3,3 3,9"></polyline>
                      <polyline points="15,3 21,3 21,9"></polyline>
                      <polyline points="9,21 3,21 3,15"></polyline>
                      <polyline points="15,21 21,21 21,15"></polyline>
                  </svg>
              </button>
          </div>
          <script>
              // Add keyboard handler for escape key to close
              document.addEventListener('keydown', function(e) {
                  if (e.key === 'Escape') {
                      try {
                          window.webkit.messageHandlers.closePlayer.postMessage('close');
                      } catch(e) {
                          console.error('Could not message Swift: ', e);
                      }
                  }
              });
              
              // Add force press handler for HLS fallback
              document.addEventListener('DOMContentLoaded', function() {
                  // Set up later when DOM is fully loaded
                  setTimeout(function() {
                      var fitButton = document.getElementById('fitButton');
                      if (fitButton) {
                          console.log("Setting up force press handler for HLS fallback");
                          // Add force press detection (long press on VisionOS)
                          var pressTimer = null;
                          
                          // For mouse devices (desktop)
                          fitButton.addEventListener('mousedown', function(e) {
                              // Start long press timer
                              pressTimer = setTimeout(function() {
                                  switchToHLS();
                                  // Mark event as handled to prevent click
                                  e.stopPropagation();
                                  e.preventDefault();
                              }, 800); // 800ms force press
                          });
                          
                          // Clear timer if released before threshold
                          fitButton.addEventListener('mouseup', function(e) {
                              if (pressTimer) {
                                  clearTimeout(pressTimer);
                                  pressTimer = null;
                              }
                          });
                          
                          // Make sure normal clicks still work
                          fitButton.onclick = function(e) {
                              // Only if not a long press
                              if (!pressTimer || e.detail > 0) {
                                  console.log("Normal click on fit button - toggling aspect ratio");
                                  toggleFitMode();
                              }
                          };
                          
                          // Clear timer if moved away
                          fitButton.addEventListener('mouseleave', function() {
                              if (pressTimer) {
                                  clearTimeout(pressTimer);
                                  pressTimer = null;
                              }
                          });
                          
                          // For touch devices (like VisionOS)
                          var touchStartTime = 0;
                          var longPressFired = false;
                          
                          fitButton.addEventListener('touchstart', function(e) {
                              touchStartTime = Date.now();
                              longPressFired = false;
                              
                              pressTimer = setTimeout(function() {
                                  longPressFired = true;
                                  switchToHLS();
                              }, 800); // 800ms force press
                          });
                          
                          // Clear timer if touch ends
                          fitButton.addEventListener('touchend', function(e) {
                              if (pressTimer) {
                                  clearTimeout(pressTimer);
                                  pressTimer = null;
                              }
                              
                              // If this was a short touch (tap), and not a long press
                              var touchDuration = Date.now() - touchStartTime;
                              if (touchDuration < 500 && !longPressFired) {
                                  console.log("Touch tap detected on fit button");
                                  
                                  // Manually trigger toggle function for taps
                                  toggleFitMode();
                                  
                                  // Prevent double execution
                                  e.preventDefault();
                              }
                          });
                          
                          // Clear timer if touch is canceled
                          fitButton.addEventListener('touchcancel', function() {
                              if (pressTimer) {
                                  clearTimeout(pressTimer);
                                  pressTimer = null;
                              }
                          });
                          
                          // Function to switch to HLS
                          function switchToHLS() {
                              // Get video element
                              var video = document.getElementById('player');
                              if (!video) return;
                              
                              // Switch to HLS fallback
                              console.log("Force press detected - switching to HLS stream");
                              
                              // Get current time to resume at the same position
                              var currentTime = video.currentTime;
                              
                              // Show feedback
                              showAspectRatioTooltip('Switching to HLS Stream');
                              
                              // Pause and switch to HLS url
                              video.pause();
                              triedHLS = true;
                              video.src = hlsUrl;
                              video.load();
                              
                              // After loading, seek to previous position
                              video.addEventListener('canplay', function resumePlay() {
                                  video.removeEventListener('canplay', resumePlay);
                                  
                                  if (currentTime > 0) {
                                      console.log("Seeking to previous position:", currentTime);
                                      try {
                                          video.currentTime = currentTime;
                                      } catch (e) {
                                          console.error("Error seeking:", e);
                                      }
                                  }
                                  
                                  // Resume playback
                                  video.play().catch(function(err) {
                                      console.error("Error playing after HLS switch:", err);
                                  });
                              });
                          }
                      }
                  }, 1000); // Give DOM time to load
              });
              
              // Simple toggle for 4:3 mode
              var isStandardMode = false; // Default widescreen mode
              function toggleFitMode() {
                  var video = document.getElementById('player');
                  var icon = document.getElementById('fitModeIcon');
                  
                  // First, remove any existing format classes
                  video.classList.remove('video-4-3');
                  video.classList.remove('video-ultrawide');
                  video.classList.remove('video-21');
                  
                  // Get current aspect ratio for better decision making
                  var aspectRatio = video.videoWidth / video.videoHeight;
                  console.log("Current aspect ratio in toggle:", aspectRatio.toFixed(2));
                  
                  if (!isStandardMode) {
                      // Switch to 4:3 mode
                      isStandardMode = true;
                      
                      // Use classlist to add the 4:3 mode
                      video.classList.add('video-4-3');
                      
                      // Log change
                      console.log("Switched to 4:3 mode");
                      
                      // Update icon to 4:3 symbol
                      icon.innerHTML = `
                          <rect x="4" y="4" width="16" height="12" rx="2" ry="2"></rect>
                          <line x1="4" y1="10" x2="20" y2="10"></line>
                      `;
                      
                      // Show feedback
                      showAspectRatioTooltip('4:3 Format Mode');
                  } else {
                      // Switch back to widescreen mode
                      isStandardMode = false;
                      
                      // Force removal of 4:3 class
                      video.classList.remove('video-4-3');
                      
                      // Log change
                      console.log("Switched to widescreen mode");
                      
                      // Update icon to "expand" arrows
                      icon.innerHTML = `
                          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                          <polyline points="9,3 3,3 3,9"></polyline>
                          <polyline points="15,3 21,3 21,9"></polyline>
                          <polyline points="9,21 3,21 3,15"></polyline>
                          <polyline points="15,21 21,21 21,15"></polyline>
                      `;
                      
                      // Show feedback
                      showAspectRatioTooltip('Original Format');
                  }
                  
                  // Also update button styling to show active mode
                  var button = document.getElementById('fitButton');
                  if (button) {
                      // Add visual feedback to button by changing its color
                      if (isStandardMode) {
                          button.style.borderColor = 'rgba(255,180,0,0.8)';
                          button.style.background = 'rgba(60,60,60,0.8)';
                      } else {
                          button.style.borderColor = 'rgba(255,255,255,0.6)';
                          button.style.background = 'rgba(0,0,0,0.5)';
                      }
                  }
                  
                  // We're already showing feedback with showAspectRatioTooltip - no need for duplicate notifications
              }
          </script>
          <script>
              // Initialize video player with HLS fallback support
              const video = document.getElementById('player');
              const loadingElement = document.getElementById('loading');
              const directUrl = "\(streamURL)\(timeParam)";
              // HLS fallback URL, will be mutable when switching scenes
              var hlsUrl = "\(hlsURL)\(timeParam)";
              
              // Initialize video with default object-fit using direct attribute
              video.setAttribute('style', 'width: 100% !important; height: 100% !important; object-fit: contain !important; position: relative !important; background-color: black !important;');
              
              // Log video dimensions when metadata is loaded
              video.addEventListener('loadedmetadata', function() {
                  var aspectRatio = video.videoWidth / video.videoHeight;
                  console.log("Video dimensions:", video.videoWidth, "x", video.videoHeight);
                  console.log("Video aspect ratio:", aspectRatio);
                  
                  // Log aspect ratio for debugging
                  var ratioText = aspectRatio.toFixed(2);
                  var isLandscape = aspectRatio > 1.0;
                  console.log("Detected aspect ratio: " + ratioText + " (" + (isLandscape ? "landscape" : "portrait") + ")");
              });
              
              // Function to show aspect ratio tooltip
              // Track active tooltips to prevent duplicates
              var activeTooltipTimer = null;
              var activeTooltip = null;
              
              function showAspectRatioTooltip(message) {
                  // Check if we already have an active tooltip
                  if (activeTooltip) {
                      // Remove existing tooltip
                      try {
                          document.body.removeChild(activeTooltip);
                      } catch (e) {}
                      
                      // Clear existing timers
                      if (activeTooltipTimer) {
                          clearTimeout(activeTooltipTimer);
                      }
                  }
                  
                  // Create new tooltip
                  var feedback = document.createElement('div');
                  feedback.style.position = 'absolute';
                  feedback.style.top = '20%';
                  feedback.style.left = '50%';
                  feedback.style.transform = 'translate(-50%, -50%)';
                  feedback.style.backgroundColor = 'rgba(0,0,0,0.75)';
                  feedback.style.color = 'white';
                  feedback.style.padding = '14px 28px';
                  feedback.style.borderRadius = '14px';
                  feedback.style.fontSize = '24px';
                  feedback.style.fontWeight = '500';
                  feedback.style.fontFamily = '-apple-system-body, -apple-system, "SF Pro Display", "SF Pro Text", "San Francisco", BlinkMacSystemFont, system-ui, sans-serif';
                  feedback.style.zIndex = '10000';
                  feedback.style.boxShadow = '0 4px 12px rgba(0,0,0,0.2)';
                  feedback.style.border = '1px solid rgba(255,255,255,0.1)';
                  feedback.style.textAlign = 'center';
                  feedback.style.letterSpacing = '-0.01em';
                  
                  // Set the message
                  feedback.textContent = message;
                  
                  // Check if this is an auto-detected message
                  if (message.includes('Auto-detected')) {
                      feedback.style.backgroundColor = 'rgba(20,20,20,0.85)';
                  }
                  
                  document.body.appendChild(feedback);
                  
                  // Save reference to active tooltip
                  activeTooltip = feedback;
                  
                  // Animate in
                  feedback.style.opacity = '0';
                  feedback.style.transition = 'opacity 0.3s ease-in-out';
                  setTimeout(function() {
                      feedback.style.opacity = '1';
                  }, 10);
                  
                  // Set up auto-removal timer
                  activeTooltipTimer = setTimeout(function() {
                      feedback.style.opacity = '0';
                      
                      setTimeout(function() {
                          try {
                              document.body.removeChild(feedback);
                              activeTooltip = null;
                          } catch (e) {}
                      }, 300);
                  }, 1500);
              }
              
              // Auto-detect video aspect ratio and add body class (already handled above)
              
              // Add another detection event for more reliability
              video.addEventListener('canplaythrough', function() {
                  // Just log that video is ready
                  console.log("Video can play through");
              }, { once: true });
              
              // Aggressive autoplay with multiple fallbacks
              function attemptAutoplay() {
                  console.log('Attempting aggressive initial autoplay');
                  
                  // Helper function for play attempts with exponential backoff
                  let attempts = 0;
                  const maxAttempts = 8;
                  
                  function attemptPlay() {
                      attempts++;
                      console.log(`Play attempt ${attempts} of ${maxAttempts}`);
                      
                      // For first attempt, try with standard settings
                      if (attempts === 1) {
                          video.play().catch(e => {
                              console.log('Initial play failed:', e);
                              setTimeout(attemptPlay, 200);
                          });
                      } 
                      // For second attempt, try with muting which helps with autoplay policies
                      else if (attempts === 2) {
                          console.log('Second attempt with muting');
                          video.muted = true;
                          video.volume = 0;
                          video.play().catch(e => {
                              console.log('Muted play failed:', e);
                              setTimeout(attemptPlay, 300);
                          });
                      }
                      // For third attempt, try with currentTime manipulation
                      else if (attempts === 3) {
                          console.log('Third attempt with time manipulation');
                          if (video.currentTime === 0) {
                              video.currentTime = 0.1;
                          } else {
                              video.currentTime = Math.max(0, video.currentTime - 0.1);
                          }
                          video.play().catch(e => {
                              console.log('Time manipulation play failed:', e);
                              setTimeout(attemptPlay, 500);
                          });
                      }
                      // For subsequent attempts, try with increasing timeouts
                      else if (attempts <= maxAttempts) {
                          console.log(`Attempt ${attempts} with additional tricks`);
                          
                          // Try different strategies based on attempt number
                          switch (attempts % 3) {
                              case 0:
                                  // Toggle controls which can help
                                  video.controls = !video.controls;
                                  break;
                              case 1:
                                  // Small time jump
                                  video.currentTime = Math.max(0, video.currentTime + 0.5);
                                  break;
                              case 2:
                                  // Toggle mute
                                  video.muted = !video.muted;
                                  break;
                          }
                          
                          video.play().catch(e => {
                              console.log(`Attempt ${attempts} failed:`, e);
                              if (attempts < maxAttempts) {
                                  setTimeout(attemptPlay, Math.min(1000, 200 * attempts));
                              } else {
                                  console.log('All autoplay attempts exhausted');
                                  // Final safety check - if we're at a non-zero time, we should ensure it's actually set
                                  let timeValue = getStartTimeFromURL();
                                  if (timeValue > 0 && video.currentTime < timeValue) {
                                      console.log('Final attempt to set correct time:', timeValue);
                                      video.currentTime = timeValue;
                                  }
                              }
                          });
                      }
                  }
                  
                  // Start the play attempts
                  attemptPlay();
              }
              
              // Helper to extract start time from URL
              function getStartTimeFromURL() {
                  let timeValue = 0;
                  if (directUrl.includes('#t=')) {
                      const timePart = directUrl.split('#t=')[1];
                      if (timePart) {
                          timeValue = parseInt(timePart, 10);
                      }
                  }
                  return timeValue;
              }
              
              // Set initial timestamp if provided via time parameter
              // This is needed for some browsers/platforms where HTML5 #t parameter isn't honored
              window.addEventListener('DOMContentLoaded', function() {
                  if (video) {
                      let timeValue = getStartTimeFromURL();
                      
                      if (timeValue > 0) {
                          console.log('Setting initial time via JavaScript: ' + timeValue + ' seconds');
                          // Set the time directly
                          try {
                              video.currentTime = timeValue;
                              // Store a reference that we manually set time
                              window.manuallySetTime = true;
                          } catch(e) {
                              console.error('Error setting initial time:', e);
                          }
                      }
                      
                      // Start aggressive autoplay attempts
                      attemptAutoplay();
                  }
              });

              let triedHLS = false;
              const fallbackTimeout = 5000; // ms to wait before HLS fallback on buffering
              let waitTimer = null;

              // Add error handling with HLS fallback
              video.addEventListener('error', function(e) {
                  console.error('Video error:', e);
                  // Clear buffering fallback timer if set
                  if (waitTimer) { clearTimeout(waitTimer); waitTimer = null; }
                  if (!triedHLS) {
                      triedHLS = true;
                      console.warn('Direct play failed, switching to HLS fallback');
                      loadingElement.innerHTML = 'Switching to HLS...';
                      video.pause();
                      video.src = hlsUrl;
                      video.load();
                      video.play().catch(err => console.error('Error playing HLS fallback:', err));
                  } else {
                      loadingElement.innerHTML = 'Error loading video. Please try again.';
                      window.webkit.messageHandlers.videoError.postMessage('Video failed to load after HLS fallback');
                  }
              });
              
              // Log when video starts playing
              video.addEventListener('playing', function() {
                  // Clear any buffering fallback timer
                  if (waitTimer) { clearTimeout(waitTimer); waitTimer = null; }
                  console.log('Video is playing');
                  
                  // Ensure volume is unmuted when playback starts
                  if (video.muted) {
                      video.muted = false;
                      video.volume = 1.0;
                      console.log('Unmuted video on playback start');
                  }
                  
                  // Check if we need to set the time on play
                  // This is a second attempt for platforms where the initial setting doesn't work
                  let timeValue = getStartTimeFromURL();
                  if (timeValue > 0 && !window.manuallySetTime) {
                      console.log('Setting time on play event: ' + timeValue + ' seconds');
                      try {
                          // Short delay to ensure video is ready
                          setTimeout(function() {
                              video.currentTime = timeValue;
                              window.manuallySetTime = true;
                          }, 200);
                      } catch(e) {
                          console.error('Error setting time on play:', e);
                      }
                  }
                  
                  // Setup periodic check to ensure video keeps playing
                  // This helps with Vision Pro quirks where some videos might pause unexpectedly
                  if (!window.playbackMonitor) {
                      window.playbackMonitor = setInterval(function() {
                          // Only attempt auto-resume if video is paused unexpectedly 
                          // AND not explicitly paused by user
                          if (video.paused && !video.ended && !document.hidden && !window.userPaused) {
                              console.log('Detected unexpected pause, attempting to resume playback');
                              video.play().catch(e => console.log('Auto-resume failed:', e));
                          }
                      }, 2000); // Check every 2 seconds
                  }
                  
                  loadingElement.style.display = 'none';
                  window.webkit.messageHandlers.videoStarted.postMessage('Video is playing');
              });
              
              // Add pause event listener to track user pausing
              video.addEventListener('pause', function() {
                  // Only if the video isn't at the end or buffering
                  if (!video.ended && !video.seeking && video.readyState >= 3) {
                      console.log('Video was paused by user or script');
                      // Let's save the pause state without doing anything else
                      // We won't auto-resume if user explicitly paused
                      
                      // Set a flag to remember user paused explicitly
                      window.userPaused = true;
                  }
              });
              
              // Make sure we respect user pause intent
              video.addEventListener('play', function() {
                  // If previously paused by user, we'll respect that
                  if (window.userPaused) {
                      window.userPaused = false; // Reset the flag now that play has happened
                  }
              });
              
              // Clean up interval when video ends
              video.addEventListener('ended', function() {
                  if (window.playbackMonitor) {
                      clearInterval(window.playbackMonitor);
                      window.playbackMonitor = null;
                  }
              });
              
              // Loading indicator with HLS fallback on prolonged buffering
              video.addEventListener('waiting', function() {
                  loadingElement.style.display = 'block';
                  loadingElement.innerHTML = 'Buffering...';
                  if (!triedHLS) {
                      if (waitTimer) clearTimeout(waitTimer);
                      waitTimer = setTimeout(function() {
                          console.warn('Buffering timeout, switching to HLS fallback');
                          triedHLS = true;
                          loadingElement.innerHTML = 'Switching to HLS...';
                          video.pause();
                          video.src = hlsUrl;
                          video.load();
                          video.play().catch(err => console.error('Error playing HLS fallback:', err));
                      }, fallbackTimeout);
                  }
              });
              
              video.addEventListener('canplay', function() {
                  // Clear any buffering fallback timer
                  if (waitTimer) { clearTimeout(waitTimer); waitTimer = null; }
                  loadingElement.style.display = 'none';
              });
              
              // Expose video controls to Swift
              window.player = {
                  play: function() { video.play(); },
                  pause: function() { video.pause(); },
                  seekTo: function(seconds) { video.currentTime = seconds; },
                  zoomIn: function(scale) {
                      video.style.transform = `scale(${scale})`;
                  },
                  zoomReset: function() {
                      video.style.transform = 'scale(1)';
                  }
              };
          </script>
      </body>
      </html>
      """

    webView.loadHTMLString(html, baseURL: URL(string: api.serverAddress))

    return webView
  }

  func updateUIView(_ webView: VideoWebView, context: Context) {
    // Updates handled by coordinator

    // Store reference to webView in coordinator for cleanup
    context.coordinator.webView = webView
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self, appModel: appModel)
  }

  class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: WebVideoPlayerView
    var appModel: AppModel
    var startTime: Double?
    var notificationObserver: NSObjectProtocol?
    var webView: VideoWebView?

    deinit {
      if let observer = notificationObserver {
        NotificationCenter.default.removeObserver(observer)
      }
    }

    init(_ parent: WebVideoPlayerView, appModel: AppModel) {
      self.parent = parent
      self.appModel = appModel

      // Log ALL possible start time sources for debugging
      print("🔍 VIDEO START TIME DEBUG:")
      print("🔍 Scene ID: \(parent.scene.id)")

      // UserDefaults values (most reliable across app boundaries)
      let savedStartTime = UserDefaults.standard.double(forKey: "last_video_start_time")
      let savedSceneId = UserDefaults.standard.string(forKey: "last_scene_id")
      print("🔍 UserDefaults start time: \(savedStartTime) for scene: \(savedSceneId ?? "none")")

      // App model values
      print("🔍 AppModel.videoStartTime: \(appModel.videoStartTime)")
      print("🔍 AppModel.selectedSceneStartTime: \(appModel.selectedSceneStartTime ?? 0)")

      // IMPORTANT: Priority order for start time values

      // 1. First check: AppModel's selectedSceneStartTime (most direct from method calls)
      if let selectedStartTime = appModel.selectedSceneStartTime, selectedStartTime > 0 {
        print("✅ Using selectedSceneStartTime: \(selectedStartTime)")
        self.startTime = selectedStartTime
      }
      // 2. Second check: AppModel's videoStartTime
      else if appModel.videoStartTime > 0 {
        print("✅ Using videoStartTime: \(appModel.videoStartTime)")
        self.startTime = appModel.videoStartTime
      }
      // 3. Third check: UserDefaults (if matches current scene)
      else if let savedSceneId = savedSceneId, savedSceneId == parent.scene.id, savedStartTime > 0 {
        print("✅ Using UserDefaults start time: \(savedStartTime)")
        self.startTime = savedStartTime
      }

      // Log final decision
      print("🎬 Final selected startTime: \(self.startTime ?? 0) for scene: \(parent.scene.id)")

      super.init()

      // Listen for video switch notifications
      notificationObserver = NotificationCenter.default.addObserver(
        forName: .videoPlayerShouldSwitch,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        guard let self = self, let webView = self.webView else { return }

        // Check if this is just a pause request
        if let pauseOnly = notification.userInfo?["pauseOnly"] as? Bool, pauseOnly {
          // Just pause the current video
          webView.evaluateJavaScript("document.getElementById('player')?.pause();") { _, error in
            if let error = error {
              print("⚠️ Error pausing video: \(error)")
            }
          }
          return
        }

        // Check if we should force play
        let forcePlay = notification.userInfo?["forcePlay"] as? Bool ?? false

        // Get scene ID and start time from notification
        guard let sceneID = notification.userInfo?["sceneID"] as? String,
          let startTime = notification.userInfo?["startTime"] as? Double
        else {
          print("⚠️ Missing scene ID or start time in notification")
          return
        }

        // Create new stream URL with the scene ID
        let api = self.appModel.api
        let streamURL = "\(api.serverAddress)/scene/\(sceneID)/stream?apikey=\(api.apiKey)"

        // Format time parameter
        let timeParam = startTime > 0 ? "#t=\(Int(startTime))" : ""
        let fullURL = "\(streamURL)\(timeParam)"
        // Prepare HLS fallback URL for this scene
        let fullHLSUrl =
          "\(api.serverAddress)/scene/\(sceneID)/stream.m3u8?resolution=ORIGINAL&apikey=\(api.apiKey)\(timeParam)"

        // Log the scene switch
        print("🔄 Switching video to: \(sceneID) at time: \(startTime)")

        // Update the video source and reset any previous fallback state
        let script = """
          (function() {
              console.log('Attempting to switch video...');
              try {
                  var video = document.getElementById('player');
                  if (!video) {
                      console.error('Player element not found');
                      return false;
                  }
                  
                  // Pause current video first
                  video.pause();
                  
                  // Reset any timers and state
                  if (typeof waitTimer !== 'undefined' && waitTimer) { 
                      clearTimeout(waitTimer);
                      waitTimer = null;
                  }
                  
                  // Reset HLS fallback state
                  triedHLS = false;
                  hlsUrl = "\(fullHLSUrl)";
                  
                  // Show the loading indicator while we switch
                  var loadingElement = document.getElementById('loading');
                  if (loadingElement) {
                      loadingElement.style.display = 'block';
                      loadingElement.innerHTML = 'Loading new video...';
                  }
                  
                  // Create timeout to handle loading errors
                  window.switchTimeout = setTimeout(function() {
                      console.log('Video switch timed out, trying HLS fallback...');
                      if (loadingElement) loadingElement.innerHTML = 'Trying alternative format...';
                      video.src = hlsUrl;
                      video.load();
                      video.play().catch(err => console.error('Error playing HLS fallback:', err));
                  }, 8000);
                  
                  // Set new source
                  video.src = "\(fullURL)";
                  video.load();
                  
                  // Set up new event listener for this load event
                  video.addEventListener('canplay', function onCanPlay() {
                      if (window.switchTimeout) {
                          clearTimeout(window.switchTimeout);
                          window.switchTimeout = null;
                      }
                      if (loadingElement) loadingElement.style.display = 'none';
                      console.log('New video can play');
                      
                      // Force controls to be visible when switching videos
                      video.controls = true;
                      
                      // Force a user interaction simulation to make controls more likely to appear
                      try {
                          // Dispatch a user interaction event to help make controls visible
                          video.dispatchEvent(new MouseEvent('mousemove', {
                              view: window,
                              bubbles: true,
                              cancelable: true
                          }));
                          
                          // Also try touching the video
                          video.dispatchEvent(new MouseEvent('mousedown', {
                              view: window,
                              bubbles: true,
                              cancelable: true
                          }));
                          
                          setTimeout(function() {
                              video.dispatchEvent(new MouseEvent('mouseup', {
                                  view: window,
                                  bubbles: true,
                                  cancelable: true
                              }));
                          }, 50);
                      } catch(e) {
                          console.log('Control visibility simulation error:', e);
                      }
                      
                      // Remove this listener after it fires once
                      video.removeEventListener('canplay', onCanPlay);
                  }, { once: true });
                  
                  // Start playback
                  var playPromise = video.play();
                  if (playPromise) {
                      playPromise.catch(err => {
                          console.error('Error playing after switch:', err);
                          // Try once more
                          setTimeout(function() {
                              video.play().catch(_ => {});
                          }, 1000);
                      });
                  }
                  
                  return true;
              } catch (err) {
                  console.error('Error during video switch:', err);
                  return false;
              }
          })();
          """

        // Execute script to change video
        webView.evaluateJavaScript(script) { result, error in
          if let error = error {
            print("⚠️ Error switching video: \(error)")
            // If JavaScript error, try the simple fallback approach
            let fallbackScript =
              "(function(){ var v = document.getElementById('player'); if(v){ v.src='\(fullURL)'; v.load(); v.play().catch(_=>{}); return true;} return false; })();"
            webView.evaluateJavaScript(fallbackScript, completionHandler: nil)
          } else if let success = result as? Bool, success {
            print("✅ Successfully switched video")

            // If forcePlay is true, make an extra effort to ensure playback starts
            if forcePlay {
              // Use a more robust play strategy with multiple attempts and different approaches
              let enhancedPlayScript = """
                (function() {
                    var video = document.getElementById('player');
                    if (!video) return false;
                    
                    console.log('Enhanced force play attempt');
                    
                    // First attempt - direct play
                    var playPromise = video.play();
                    
                    // Set up multiple subsequent attempts with delay
                    setTimeout(function() {
                        console.log('Second play attempt');
                        video.play().catch(function(e) {
                            console.log('Second attempt failed:', e);
                            
                            // One more attempt with muting as last resort (helps with autoplay policies)
                            setTimeout(function() {
                                console.log('Third play attempt with muting as last resort');
                                // Only mute if still not playing after multiple attempts
                                if (video.paused) {
                                    video.muted = true;
                                    video.play();
                                }
                            }, 200);
                        });
                    }, 300);
                    
                    return true;
                })();
                """

              webView.evaluateJavaScript(enhancedPlayScript, completionHandler: nil)

              // Also send a forcePlayRequest notification which triggers our more robust handler
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                  name: NSNotification.Name("forcePlayRequest"), object: nil)
              }
            }
          } else {
            print("❌ Failed to switch video, trying fallback")
            // Try more direct approach as fallback
            let fallbackScript =
              "(function(){ var v = document.getElementById('player'); if(v){ v.src='\(fullURL)'; v.load(); v.play().catch(_=>{}); return true;} return false; })();"
            webView.evaluateJavaScript(fallbackScript, completionHandler: nil)

            // Always try to play again after a short delay to ensure playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
              webView.evaluateJavaScript(
                "document.getElementById('player')?.play().catch(e => {});", completionHandler: nil)
            }
          }
        }
      }
    }

    func getStartTime() -> Double? {
      return startTime
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      print("✅ WebView loaded successfully")

      // Store webView reference
      self.webView = webView as? VideoWebView

      // Add message handlers for JavaScript communication
      // First remove any existing message handlers to prevent duplicate registration
      webView.configuration.userContentController.removeScriptMessageHandler(
        forName: "videoStarted")
      webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoError")
      webView.configuration.userContentController.removeScriptMessageHandler(forName: "closePlayer")

      // Add the message handlers
      webView.configuration.userContentController.add(self, name: "videoStarted")
      webView.configuration.userContentController.add(self, name: "videoError")
      webView.configuration.userContentController.add(self, name: "closePlayer")

      // Update loading state
      parent.onLoadingStateChanged(false)
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      print("⚠️ WebView navigation error: \(error.localizedDescription)")
      parent.onLoadingStateChanged(false)
    }

    func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      if message.name == "videoStarted" {
        print("📱 Video started playing in web view")
        parent.onLoadingStateChanged(false)
      } else if message.name == "videoError" {
        print("⚠️ Video error in web view: \(message.body)")
        parent.onLoadingStateChanged(false)
      } else if message.name == "closePlayer" {
        print("🚪 Close message received from web view")

        // Force dismiss via AppModel to ensure navigation state is clean
        DispatchQueue.main.async {
          // Stop sound by pausing the video first with a more robust script that avoids redeclaration
          if let webView = self.webView as? VideoWebView {
            // First unload the current video
            webView.evaluateJavaScript(
              """
                  (function() {
                      // Immediately kill all audio
                      let videoEl = document.getElementById('player');
                      if (videoEl) { 
                          // Mute first to prevent any transition sounds
                          videoEl.volume = 0;
                          videoEl.muted = true;
                          
                          // Pause and unload
                          videoEl.pause(); 
                          videoEl.removeAttribute('src');
                          videoEl.load();
                          
                          // Set video element to null
                          videoEl.outerHTML = '';
                      }
                      
                      // Ensure ALL audio is stopped on the page
                      document.querySelectorAll('audio, video').forEach(media => {
                          media.volume = 0;
                          media.muted = true;
                          media.pause();
                          media.removeAttribute('src');
                          media.load();
                          media.outerHTML = '';
                      });
                      
                      // Clear any playback intervals that might be trying to restart
                      if (window.playbackMonitor) {
                          clearInterval(window.playbackMonitor);
                          window.playbackMonitor = null;
                      }
                      
                      // Add an empty audio context to force audio to get cleaned up
                      try {
                          let audioContext = new (window.AudioContext || window.webkitAudioContext)();
                          audioContext.close();
                      } catch (e) {
                          console.log('Could not create audio context for cleanup:', e);
                      }
                      
                      return true;
                  })();
              """, completionHandler: nil)
          }

          // Stop all previews to ensure complete audio cleanup
          GlobalVideoManager.shared.stopAllPreviews()

          appModel.isShowingPlayer = false

          // Also call dismiss to ensure view is removed
          if let dismiss = self.parent.onDismiss {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
  let scene: StashScene
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var appModel: AppModel
  @EnvironmentObject private var navigationModel: NavigationModel
  @State private var showControls = true
  @State private var hideControlsTask: Task<Void, Never>?
  @State private var isLoading = true
  @State private var feedbackMessage: String = ""
  @State private var showingFeedback = false
  @State private var showingTechnicalInfo = false

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Background
        Color.black.ignoresSafeArea()

        // Web video player
        WebVideoPlayerView(
          scene: scene,
          onLoadingStateChanged: { isPlayerLoading in
            self.isLoading = isPlayerLoading
          },
          onDismiss: {
            print("🚪 Web player requested dismiss")
            isLoading = false
            appModel.isShowingPlayer = false
            dismiss()
          }
        )
        .frame(width: geometry.size.width, height: geometry.size.height)
        .ignoresSafeArea()

        // Loading overlay
        if isLoading {
          WebPlayerStatusView(message: "Loading video...")
        }

        // Technical info overlay
        VideoInfoOverlay(
          scene: scene,
          isVisible: showingTechnicalInfo
        )
        .animation(.easeInOut(duration: 0.3), value: showingTechnicalInfo)

        // Feedback overlay for time skipping
        if showingFeedback {
          VStack {
            Text(feedbackMessage)
              .font(.system(size: 40, weight: .bold))
              .foregroundColor(.white)
              .padding(20)
              .background(
                RoundedRectangle(cornerRadius: 15)
                  .fill(Color.black.opacity(0.7))
              )
          }
          .transition(.opacity)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        // Custom controls overlay - put all buttons on same overlay
        if showControls {
          VStack {
            // Top padding to push buttons down
            Spacer().frame(height: 100)

            HStack(spacing: 20) {
              // Close button
              Button(action: {
                print("Close button pressed")
                isLoading = false
                // Stop audio playback before dismissing with improved script
                NotificationCenter.default.post(
                  name: NSNotification.Name("executeJavaScript"),
                  object: nil,
                  userInfo: [
                    "script": """
                        (function() {
                            // Immediately kill all audio
                            let videoEl = document.getElementById('player');
                            if (videoEl) { 
                                // Mute first to prevent any transition sounds
                                videoEl.volume = 0;
                                videoEl.muted = true;
                                
                                // Pause and unload
                                videoEl.pause(); 
                                videoEl.removeAttribute('src');
                                videoEl.load();
                                
                                // Remove video element completely
                                videoEl.outerHTML = '';
                            }
                            
                            // Ensure ALL audio is stopped on the page
                            document.querySelectorAll('audio, video').forEach(media => {
                                media.volume = 0;
                                media.muted = true;
                                media.pause();
                                media.removeAttribute('src');
                                media.load();
                                media.outerHTML = '';
                            });
                            
                            // Clear any playback intervals that might be trying to restart
                            if (window.playbackMonitor) {
                                clearInterval(window.playbackMonitor);
                                window.playbackMonitor = null;
                            }
                            
                            // Add an empty audio context to force audio to get cleaned up
                            try {
                                let audioContext = new (window.AudioContext || window.webkitAudioContext)();
                                audioContext.close();
                            } catch (e) {
                                console.log('Could not create audio context for cleanup:', e);
                            }
                            
                            return true;
                        })();
                    """
                  ]
                )

                // Force navigation exit
                DispatchQueue.main.async {
                  // Stop all previews to ensure complete audio cleanup
                  GlobalVideoManager.shared.stopAllPreviews()
                  appModel.isShowingPlayer = false
                  dismiss()
                }
              }) {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 40))  // Bigger button
                  .foregroundStyle(.white)
                  .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
                  .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 50, height: 50))
              }
              .buttonStyle(.plain)

              // Technical info button
              Button(action: {
                withAnimation {
                  showingTechnicalInfo.toggle()
                }
              }) {
                Image(systemName: showingTechnicalInfo ? "info.circle.fill" : "info.circle")
                  .font(.system(size: 30))
                  .foregroundStyle(showingTechnicalInfo ? .blue : .white)
                  .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
              }
              .buttonStyle(.plain)

              // Pure random video button (picks a random video but starts from beginning)
              Button(action: {
                print("Random button pressed")
                Task {
                  await playRandomScene(randomPosition: false)
                }
              }) {
                Image(systemName: "shuffle")
                  .font(.system(size: 30))
                  .foregroundStyle(.white)
                  .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
              }
              .buttonStyle(.plain)

              // Random jump button (picks a random video and starts at a random position)
              Button(action: {
                print("Random position button pressed")
                Task {
                  await playRandomScene(randomPosition: true)
                }
              }) {
                Image(systemName: "shuffle.circle.fill")
                  .font(.system(size: 30))
                  .foregroundStyle(.purple)
                  .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
              }
              .buttonStyle(.plain)

              Spacer()
            }
            .padding(.horizontal, 20)
            .zIndex(100)  // Ensure it's always on top

            Spacer()
          }
          .transition(AnyTransition.opacity)
        }
      }
      .onTapGesture {
        toggleControls()
      }
      // Add the drag gesture for seeking
      .gesture(
        DragGesture(minimumDistance: 30)
          .onEnded { value in
            let dx = value.translation.width
            let dy = value.translation.height

            // Only respond to horizontal drags
            guard abs(dx) > abs(dy) else { return }

            // Find all VideoWebView instances in the entire view hierarchy
            NotificationCenter.default.post(
              name: NSNotification.Name("TimeSkipRequest"),
              object: nil,
              userInfo: ["seconds": dx > 0 ? 30.0 : -10.0]
            )

            // Show a visual indicator
            let skipText = dx > 0 ? "▶▶ 30s" : "◀◀ 10s"

            // Show visual feedback as a simple overlay
            withAnimation {
              showFeedback(skipText)
            }
          }
      )
    }
    .edgesIgnoringSafeArea(.all)
    .statusBarHidden(true)
    .navigationBarHidden(true)
    .onAppear {
      startHideControlsTimer()

      // More aggressive approach to ensure video starts playing immediately
      // with multiple staggered attempts
      print("🎬 VideoPlayerView appeared - starting aggressive autoplay sequence")

      // First immediate attempt
      NotificationCenter.default.post(
        name: NSNotification.Name("forcePlayRequest"),
        object: nil
      )

      // Then schedule a series of additional attempts with increasing delays
      let delays = [0.3, 0.7, 1.2, 2.0, 3.0]
      for (index, delay) in delays.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          print("🎬 Scheduled autoplay attempt \(index + 1)")
          NotificationCenter.default.post(
            name: NSNotification.Name("forcePlayRequest"),
            object: nil
          )
        }
      }
    }
  }

  // MARK: - Helper Methods

  private func toggleControls() {
    withAnimation {
      showControls.toggle()
    }

    if showControls {
      startHideControlsTimer()
    } else {
      hideControlsTask?.cancel()
    }
  }

  private func startHideControlsTimer() {
    hideControlsTask?.cancel()
    hideControlsTask = Task {
      do {
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        if !Task.isCancelled {
          await MainActor.run {
            withAnimation {
              showControls = false
            }
          }
        }
      } catch {
        // Task cancelled
      }
    }
  }

  private func showFeedback(_ message: String) {
    feedbackMessage = message
    withAnimation {
      showingFeedback = true
    }

    // Hide feedback after 1 second
    Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      await MainActor.run {
        withAnimation {
          showingFeedback = false
        }
      }
    }
  }

  // MARK: - Random Video Methods

  private func playPureRandomVideo() {
    Task {
      await playRandomScene(randomPosition: false)
    }
  }

  private func playRandomVideo() {
    Task {
      await playRandomScene(randomPosition: true)
    }
  }

  private func playRandomScene(randomPosition: Bool) async {
    print("🎲 Starting random scene selection, randomPosition: \(randomPosition)")

    // Show loading indicator without dismissing the player
    await MainActor.run {
      isLoading = true
    }

    let api = appModel.api
    // Fetch a random scene using the API's random sort
    do {
      try await api.fetchScenes(page: 1, sort: "random")

      // Select a random scene, excluding the current one if possible
      let allScenes = api.scenes
      let filteredScenes: [StashScene] = {
        if let current = appModel.currentScene {
          return allScenes.filter { $0.id != current.id }
        } else {
          return allScenes
        }
      }()
      guard let randomScene = (filteredScenes.isEmpty ? allScenes : filteredScenes).randomElement()
      else {
        print("⚠️ No random scenes found")
        await MainActor.run {
          isLoading = false
        }
        return
      }
      print("🎲 Selected random scene: \(randomScene.id) - \(randomScene.title)")

      // Calculate a random start time if needed
      var randomStartTime: Double = 0
      if randomPosition {
        let videoDuration = randomScene.files?.first?.duration ?? 0
        if videoDuration > 0 {
          let minimumStartTime = min(5 * 60, videoDuration * 0.25)
          let maximumStartTime = videoDuration * 0.75
          if maximumStartTime > minimumStartTime {
            randomStartTime = Double.random(in: minimumStartTime...maximumStartTime)
          } else {
            randomStartTime = videoDuration > 300 ? 300 : 0
          }
          print("🎲 Using random start time: \(randomStartTime) seconds")
        }
      }

      // First, ensure all preview players are stopped
      GlobalVideoManager.shared.stopAllPreviews()

      // Reset any existing player state before switching
      await MainActor.run {
        // Stop current video to prevent conflicts - use a direct notification approach
        NotificationCenter.default.post(
          name: .videoPlayerShouldSwitch, object: nil,
          userInfo: ["pauseOnly": true])
      }

      // Update the scene via notification
      await MainActor.run {
        appModel.videoStartTime = randomStartTime
        appModel.selectedSceneStartTime = randomStartTime
        appModel.currentScene = randomScene
        appModel.selectedScene = randomScene
        isLoading = true  // Keep loading state until we've actually started playback
        print("🎲 Set new scene: \(randomScene.title)")

        // Use a small delay to ensure clean switching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          // First save to UserDefaults to ensure persistence across all boundaries
          UserDefaults.standard.set(randomStartTime, forKey: "last_video_start_time")
          UserDefaults.standard.set(randomScene.id, forKey: "last_scene_id")
          UserDefaults.standard.synchronize()

          // Then send the switch message
          NotificationCenter.default.post(
            name: .videoPlayerShouldSwitch, object: nil,
            userInfo: [
              "sceneID": randomScene.id,
              "startTime": randomStartTime,
              "forcePlay": true
            ])

          // Send a stronger series of forcibly spaced play attempts to ensure playback happens
          // Start sooner with 0.3s delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // First force play request
            print("🚀 First force play attempt")
            NotificationCenter.default.post(
              name: NSNotification.Name("forcePlayRequest"), object: nil)

            // Schedule a sequence of follow-up attempts with increasing delays
            var delays = [0.4, 0.8, 1.5, 2.5]
            for (index, delay) in delays.enumerated() {
              DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                print("🚀 Follow-up play attempt \(index + 1)")
                NotificationCenter.default.post(
                  name: NSNotification.Name("forcePlayRequest"), object: nil)

                // When reaching the last attempt, hide the loading indicator
                // and ensure controls are visible
                if index == delays.count - 1 {
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoading = false

                    // Force controls visible after random jump
                    // by making sure our control overlay is visible
                    withAnimation {
                      self.showControls = true
                    }
                    self.startHideControlsTimer()

                    // Also send a direct JavaScript command to make native controls visible
                    let forceControlsScript = """
                      (function() {
                          var video = document.getElementById('player');
                          if (video) {
                              // Ensure controls are enabled
                              video.controls = true;
                              
                              // Simulate user interaction to make controls appear
                              try {
                                  // First try mouse events
                                  ['mousemove', 'mousedown', 'mouseup', 'click'].forEach(function(eventType) {
                                      video.dispatchEvent(new MouseEvent(eventType, {
                                          bubbles: true,
                                          cancelable: true,
                                          view: window
                                      }));
                                  });
                                  
                                  // Then try touch events for mobile/Vision Pro
                                  try {
                                      video.dispatchEvent(new TouchEvent('touchstart', {
                                          bubbles: true,
                                          cancelable: true,
                                          view: window
                                      }));
                                      
                                      setTimeout(function() {
                                          video.dispatchEvent(new TouchEvent('touchend', {
                                              bubbles: true,
                                              cancelable: true,
                                              view: window
                                          }));
                                      }, 50);
                                  } catch(e) {}
                                  
                                  return true;
                              } catch(e) {
                                  console.error('Control visibility error:', e);
                                  return false;
                              }
                          }
                          return false;
                      })();
                      """

                    NotificationCenter.default.post(
                      name: NSNotification.Name("executeJavaScript"),
                      object: nil,
                      userInfo: ["script": forceControlsScript]
                    )
                  }
                }
              }
            }
          }
        }
      }
    } catch {
      print("❌ Error fetching random video: \(error)")
      await MainActor.run {
        isLoading = false
      }
    }
  }
}

// MARK: - Web Player Status View
struct WebPlayerStatusView: View {
  let message: String

  var body: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(2.0)

      Text(message)
        .font(.headline)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}
