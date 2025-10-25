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

## VR Immersive Player ✅
  - **Full Format Support**: Automatic detection and rendering of VR video formats
    - Side-by-Side (SBS) 180° and 360°
    - Over-Under (OU) 180° and 360°
    - Fisheye 180° and 360° with equidistant projection correction
  - **Format Detection**: Intelligent auto-detection from scene tags and titles
    - Tags: "180", "360", "sbs", "ou", "fisheye", "eac", etc.
    - Aspect ratio validation and format switching
    - Manual format cycling via on-screen button
  - **Peripheral Coverage**: Full 180° (π radians) or 360° (2π radians) field of view
    - Curved mesh surface with adaptive segment counts
    - 32+ segments for fisheye (smooth distortion correction)
    - 64+ segments for 360° (complete wraparound)
  - **Gesture Controls**: Natural Vision Pro hand gesture support
    - **Horizontal drag**: Rotate view left/right (yaw)
    - **Vertical drag**: Tilt view up/down (pitch ±45°)
    - **Two-hand pinch**: Zoom in/out (0.5x to 3x scale)
    - All gestures work simultaneously and smoothly
  - **Fisheye Projection**: Proper equidistant projection correction
    - Radial distortion mapping from spherical to texture coordinates
    - Supports both SBS and OU fisheye layouts
    - Adaptive FOV calculation based on 180°/360° detection
  - **Playback Features**:
    - Random jump with random start position
    - Play/pause controls with buffer monitoring
    - Auto-recovery from playback stalls (3-step fallback)
    - Format picker for manual override

  **Implementation Files**:
  - `ImmersiveVideoScene.swift` - Main VR player with RealityKit mesh rendering
  - `VRLibraryView.swift` - VR content browser with tag-based filtering
  - `VRFormat` enum - Format detection and properties (is180, is360, isFisheye, etc.)

  **Key Technical Details**:
  - Uses RealityKit VideoMaterial with AVPlayer for video rendering
  - Custom curved mesh with proper UV mapping for each format type
  - Quaternion-based rotation (yaw × pitch) for smooth orientation
  - Scale transformation applied to mesh entity for zoom
  - MagnifyGesture and DragGesture for multi-touch interaction
  - Format-aware mesh recreation when VR format changes
  - 4-step playback recovery with HLS fallback for codec compatibility
  - Proper window management with immersive space state tracking

  **Recent Fixes (2025-10-25)**:
  - ✅ Fixed video playback by restoring proper UV-mapped curved surface mesh
  - ✅ Added HLS streaming fallback for codec compatibility (HEVC, VC-1, etc.)
  - ✅ Fixed main interface visibility - properly hides during VR immersion
  - ✅ Added immersive space state management (.open, .closed, .inTransition)
  - ✅ Implemented dynamic mesh recreation when VR format changes
  - ✅ Added 4-step playback recovery: resume → seek → reload → HLS fallback

## VR Video Architecture Deep Dive 📐

### Core Problem: UV Mapping for VR Video Formats

**The Challenge**: VR videos are encoded with multiple viewing perspectives in a single 2D video file. The app must correctly map these 2D textures onto a 3D viewing surface.

**VR Format Types**:
1. **Side-by-Side (SBS)**: Left and right eye views are horizontally adjacent
   - Left eye: texture coordinates U = 0.0 to 0.5
   - Right eye: texture coordinates U = 0.5 to 1.0
   - Vision Pro uses left eye view

2. **Over-Under (OU)**: Top and bottom eye views are vertically stacked
   - Top eye: texture coordinates V = 0.0 to 0.5
   - Bottom eye: texture coordinates V = 0.5 to 1.0
   - Vision Pro uses top view

3. **Fisheye**: Circular fisheye projection requiring distortion correction
   - Equidistant projection: radial distance maps to angle
   - Formula: `r = θ * radius / fov` (where θ is angle from center)
   - Requires inverse mapping from texture to sphere coordinates

4. **180° vs 360°**: Field of view affects horizontal wraparound
   - 180°: Horizontal FOV = π radians (half sphere)
   - 360°: Horizontal FOV = 2π radians (full sphere wraparound)

### Critical UV Mapping Implementation

**The Bug**: Previous code used RealityKit's built-in sphere with negative scale:
```swift
// ❌ BROKEN: Inverts geometry but breaks UV coordinates
let mesh = MeshResource.generateSphere(radius: 2.0)
entity.scale = [-1, 1, 1]  // Flips X-axis for inside viewing
```

**The Fix**: Custom mesh generation with proper UV mapping:
```swift
// ✅ CORRECT: Custom mesh with format-specific UV coordinates
func createCurvedSurface(radius: Float, format: VRFormat) -> MeshData {
  // Generate vertices in 3D space based on spherical coordinates
  for vIdx in 0...vSegments {
    for hIdx in 0...hSegments {
      // Spherical to Cartesian conversion
      let phi = (Float(vIdx) / Float(vSegments) - 0.5) * vFov
      let theta = (Float(hIdx) / Float(hSegments)) * hFov - hFov / 2

      let x = radius * cos(phi) * sin(theta)
      let y = radius * sin(phi)
      let z = -radius * cos(phi) * cos(theta)

      vertices.append(SIMD3(x, y, z))

      // Calculate UV coordinates based on VR format
      var u = Float(hIdx) / Float(hSegments)
      var v = Float(vIdx) / Float(vSegments)

      // Adjust for SBS (use left half of texture)
      if format.isSideBySide {
        u = u * 0.5  // Map to 0.0-0.5 range
      }

      // Adjust for OU (use top half of texture)
      if format.isOverUnder {
        v = v * 0.5  // Map to 0.0-0.5 range
      }

      // Fisheye projection correction
      if format.isFisheye {
        let centerU = u - 0.5
        let centerV = v - 0.5
        let r = sqrt(centerU * centerU + centerV * centerV)
        let theta = atan2(centerV, centerU)

        // Equidistant projection formula
        let newR = r * fov / (2.0 * Float.pi)
        u = 0.5 + newR * cos(theta)
        v = 0.5 + newR * sin(theta)
      }

      uvs.append(SIMD2(u, v))
    }
  }
}
```

### Mesh Density Optimization

**Segment Counts** (higher = smoother but more GPU load):
- **Standard VR**: 16 vertical × 32 horizontal segments
- **Fisheye**: 32 vertical segments for smooth distortion correction
- **360°**: 64 horizontal segments for complete wraparound without seams

**Why Segment Count Matters**:
- Too few segments: Visible polygon edges, distortion artifacts
- Too many segments: GPU performance impact, unnecessary detail
- Fisheye needs more segments because distortion correction requires finer mesh

### RealityKit Integration

**VideoMaterial Pipeline**:
```swift
// 1. Create AVPlayer with video URL
let player = AVPlayer(url: videoURL)

// 2. Create VideoMaterial from player
let videoMaterial = try VideoMaterial(avPlayer: player)

// 3. Generate custom mesh with proper UVs
let surfaceData = createCurvedSurface(radius: 2.0, format: .sbs180)
var descriptor = MeshDescriptor(name: "vr-video-surface")
descriptor.positions = MeshBuffer(surfaceData.vertices)
descriptor.textureCoordinates = MeshBuffer(surfaceData.uvs)
descriptor.normals = MeshBuffer(surfaceData.normals)
descriptor.primitives = .triangles(surfaceData.indices)

// 4. Generate GPU mesh resource
let mesh = try MeshResource.generate(from: [descriptor])

// 5. Create entity and apply video material
let entity = ModelEntity(mesh: mesh, materials: [videoMaterial])
rootEntity.addChild(entity)

// 6. Start playback
player.play()
```

### 4-Step Playback Recovery System

**Problem**: Video playback can fail for multiple reasons - network issues, codec incompatibility, buffer starvation, format errors.

**Solution**: Progressive escalation through recovery strategies:

1. **Step 1: Simple Resume** (0% destructive)
   - Just call `player.play()` again
   - Handles temporary pauses, minor buffering hiccups
   - Wait 1 second to assess effectiveness

2. **Step 2: Seek Forward** (10% destructive)
   - Seek ahead 1 second: `player.seek(to: currentTime + 1)`
   - Skips potentially corrupted frames or stuck buffer positions
   - Wait 1 second to assess effectiveness

3. **Step 3: Reload Player Item** (50% destructive)
   - Create fresh `AVPlayerItem` from same `AVURLAsset`
   - Increase buffer: `item.preferredForwardBufferDuration = 20`
   - Seek to previous position and restart
   - Wait 2 seconds to assess effectiveness

4. **Step 4: HLS Fallback** (100% format change)
   - Switch from direct streaming to HLS with transcoding
   - Uses Stash server's built-in HEVC/H.264 transcoding
   - Only attempted once per session (`hlsFallbackAttempted` flag)
   - Critical for HEVC, VC-1, WMV videos that don't play natively
   - Works seamlessly with VPN optimizations

**Why HLS is Last Resort**:
- Adds server CPU load (transcoding)
- Introduces slight latency
- Lower quality than direct play for compatible formats
- But: Works for 100% of videos regardless of codec

### Window Management & Immersive Space

**Problem**: visionOS default behavior shows system UI overlays in immersive spaces.

**Solution**: Three-part hiding system:

1. **Immersive Space Configuration**:
```swift
ImmersiveSpace(id: "ImmersiveVideoSpace") {
  ImmersiveVideoScene()
    .persistentSystemOverlays(.hidden)  // Hide status bar, controls
    .upperLimbVisibility(.hidden)        // Hide hand/controller UI
}
.immersionStyle(selection: .constant(.full), in: .full)
```

2. **State Management**:
```swift
enum ImmersiveSpaceState {
  case closed      // Not in VR
  case inTransition // Opening/closing
  case open        // Fully immersed
}
```

3. **Cleanup on Exit**:
```swift
.onDisappear {
  cleanupResources()
  appModel.immersiveSpaceState = .closed
  appModel.isShowingImmersiveSpace = false
}
```

**Critical**: Must reset state on exit or main interface won't restore properly.

### Dynamic Format Switching

**Challenge**: User can change VR format while video is playing (e.g., switch from SBS 180° to Fisheye 360°).

**Solution**: Watch for format changes and rebuild mesh:
```swift
.onChange(of: vrFormat) { oldValue, newValue in
  guard oldValue != newValue else { return }

  // Remove old sphere
  sphereEntity?.removeFromParent()
  sphereEntity = nil

  // Create new mesh with correct UV mapping for new format
  let surfaceData = createCurvedSurface(radius: 2.0, format: newValue)
  // ... generate new mesh ...

  // Video continues playing seamlessly with new projection
}
```

### Gesture Controls Architecture

**Rotation (Yaw + Pitch)**:
```swift
DragGesture()
  .onChanged { value in
    // Horizontal drag = yaw (Y-axis rotation)
    rotation += Float(value.translation.width) * 0.005

    // Vertical drag = pitch (X-axis rotation, clamped ±45°)
    tiltAngle = max(-0.785, min(0.785,
      tiltAngle - Float(value.translation.height) * 0.005))
  }

// Combine rotations using quaternions
let tiltRotation = simd_quatf(angle: tiltAngle, axis: [1, 0, 0])
let yawRotation = simd_quatf(angle: rotation, axis: [0, 1, 0])
entity.orientation = yawRotation * tiltRotation
```

**Why Quaternions?**:
- Avoid gimbal lock (Euler angles fail at 90° pitch)
- Smooth interpolation between orientations
- Mathematically cleaner composition (multiplication vs matrix math)

**Zoom (Pinch)**:
```swift
MagnifyGesture()
  .onChanged { value in
    scale = max(0.5, min(3.0, value.magnification))
  }

entity.scale = [scale, scale, scale]
```

### Performance Considerations

**GPU Optimization**:
- Mesh generation happens once per format change, not per frame
- RealityKit caches mesh resources automatically
- VideoMaterial updates GPU texture every frame (hardware accelerated)

**Memory Management**:
- Explicitly cleanup player and materials on exit
- Remove entities from parent before deallocating
- Stop all observers and timers to prevent leaks

**Network Optimization** (see VPN section):
- Direct streaming preferred for local network
- HLS fallback for VPN/remote to handle transcoding
- Single Bearer token auth to minimize handshakes