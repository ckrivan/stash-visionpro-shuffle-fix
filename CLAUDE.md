# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands
- Build app: `xcodebuild -project Stash.xcodeproj -scheme Stash -configuration Debug build`
- Build & run logs: `xcodebuild -project Stash.xcodeproj -scheme Stash -configuration Debug build 2>&1 | tee build.log`
- Run tests: `xcodebuild test -project Stash.xcodeproj -scheme Stash -destination 'platform=visionOS Simulator'`
- Run specific test: `xcodebuild test -project Stash.xcodeproj -scheme Stash -destination 'platform=visionOS Simulator' -only-testing:StashTests/SomeTestClass/testSomeFunction`

## Claude Code Behavior
- **Auto-Execute**: Run xcodebuild commands yourself and report detailed error messages
- **Error Analysis**: When build errors occur, provide context and suggested fixes
- **File Creation**: Do not create new files unless explicitly confirmed by the user
- **Code Changes**: Make minimal targeted changes to existing files
- **Validation**: After making changes, run builds to verify the changes work as expected

## Code Style
- **Architecture**: MVVM with SwiftUI
- **Organization**: Features/, Models/, Networking/, Utilities/
- **Types**: Prefer structs over classes; use protocols for shared behavior
- **State Management**: Use @State, @Published, @StateObject properly
- **Naming**: camelCase for vars/funcs, PascalCase for types; Boolean: use is/has/should prefixes
- **Concurrency**: Use async/await, not completion handlers
- **Errors**: Use Result type; add logging for repeated errors

## VisionOS Guidelines
- Always develop with VisionOS in mind - check compatibility regularly
- Use RealityKit for spatial experiences
- Support both immersive and window-based interactions
- Test all features in Vision Pro simulator
- Handle hand tracking and eye tracking appropriately
- Optimize performance for Vision Pro (60fps target)
- Follow Apple's visionOS Human Interface Guidelines

## Logging
- Add detailed logs for repeated errors
- Use Logger for structured logging
- Include context and state information in log messages

## Video Handling
- **Playback Strategy**: Use appropriate streaming method based on codec:
  - H.264 and compatible formats: Start with direct playback for best performance
  - HEVC/H.265 and problematic formats: Use HLS with transcoding by default
- **Codec Handling**:
  - H.264: Direct play works well - preferred for performance
  - HEVC/H.265: Use HLS by default (following Stash's own behavior)
  - WMV/VC-1: Problematic on Apple platforms - use HLS with transcoding
  - Container formats (MP4, MKV, etc.): Compatibility depends on the codec inside
- **Auto-Fallback**: System detects playback issues and automatically falls back to HLS streaming
- **Transcoding**: Uses Stash's built-in transcoding with HLS resolution options (720p, 480p, 240p)
- **Video Reset**: When switching to a new video, always reset to direct play for optimal performance

## Stash API Documentation
- **Streaming API**: 
  - Direct Stream: `/scene/{id}/stream` - Best for compatible formats (H.264)
  - HLS Stream: `/scene/{id}/stream.m3u8` - Uses transcoding for better compatibility
  - HLS with Resolution: `/scene/{id}/stream.m3u8?resolution=720p` - Specify quality (240p, 480p, 720p, etc.)
- **GraphQL API**: `POST /graphql` - Used for all data queries
  - Finding scenes: `FindScenes` operation with filters
  - Scene details: `findScene(id: ID!)` query
  - Performers: `findPerformers` query
  - Scene markers: `findSceneMarkers` query
- **Thumbnails & Sprites**:
  - VTT: Generated WebVTT files for scrubbing thumbnails
    - Path: `/.stash/generated/vtt/{oshash}_thumbs.vtt`
    - URL path for VTT: `/vtt/{oshash}_thumbs.vtt`
  - Sprite Sheet: Generated thumbnail grids
    - Path: `/.stash/generated/vtt/{oshash}_sprite.jpg`
    - URL path for sprite: `/vtt/{oshash}_sprite.jpg`
  - Access: Based on file OSHash, not scene ID
  - Generation: Stash generates these automatically when configured
- **Web UI Access**: Default port is 9999 (configurable)
- **API Key Authentication**: Required in all requests
  - Add as a header: `ApiKey` or `Authorization: Bearer {apiKey}`
  - Query parameter: `?apikey={apiKey}`

- Notify before making major architectural changes. Follow Apple's documentation for implementation details.
- https://developer.apple.com/documentation - make sure you are using this as well with most up to date information
ALSO VERY IMPORTANT WHEN WE ADD NEW FEATURES MAKE SURE TO NOTATE THEM HERE ONCE WE KNOW THEY ARE WORKING.

## VPN Detection & Optimization ✅
  - **Auto-detect VPN usage** via network interfaces (utun, tun, ppp, ipsec, wg)
  - **Network modes**: Local, VPN, Remote with different optimization strategies
  - **VPN optimizations**:
    - Default to direct streaming first, then HLS fallback
    - Use single Bearer token authentication (eliminates redundant handshakes)  
    - Skip codec detection API calls (reduces pre-playback requests from 5-8 to 1)
    - Defer thumbnail/VTT loading until after video starts
    - Reduced retry attempts and connection pooling
  - **Local network**: Full-featured mode with codec detection and thumbnails
  - **Remote network**: HLS transcoding preferred for reliability

  **Key insight**: When local (no VPN), latency is ~1ms so multiple API calls are fine. 
  Over VPN, even WireGuard adds 20-50ms per call, making 5-8 pre-playback calls feel sluggish.
  
  **Implementation**: 
  - `NetworkMonitor` class detects VPN/network state
  - `StashAPI.getOptimizedStreamRequest()` chooses strategy based on network mode
  - `VideoPlayerUtility` has VPN-optimized thumbnail/VTT methods
  - VPN detection works without MainActor dependencies for utility classes

## Hardcoded Credentials & Auto-Connect ✅
  - **No Manual Input Required**: API key and server address are hardcoded in app
  - **Auto-Connection**: App automatically connects on launch using saved credentials
  - **Seamless Experience**: Users no longer need to enter server details or API keys
  - **VPN Status Indicator**: Shows current network mode (Local, VPN, Remote) in sidebar
    - Blue shield icon for VPN connections with pulse effect
    - Green house icon for local network
    - Orange network icon for remote connections
    - Tap indicator for detailed network information and optimization status
  
  **Files Updated**:
  - `ConnectionView.swift` - Uses hardcoded credentials, auto-connects
  - `ContentView.swift` - Updated ServerConnectionView with hardcoded values  
  - `MainVisionView.swift` - Added VPN status indicator to sidebar
  - `VPNStatusIndicator.swift` - New component showing network status with details popover