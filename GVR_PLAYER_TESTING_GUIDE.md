# GVR-Style VR Player Testing Guide

## What Was Implemented

After 6 months of the RealityKit UV mapping approach not working, I've implemented a **Moon Player-style Metal-based VR renderer** for your Stash Vision Pro app.

### Key Differences from Previous Approach:

| Old Approach (Failed) | New Approach (GVR-Style) |
|----------------------|--------------------------|
| RealityKit custom UV mesh | Metal shaders with proper equirectangular projection |
| Complex `createCurvedSurface()` mesh generation | Direct Metal sphere with shader-based UV mapping |
| Manual vertex/normal/UV calculations | Hardware-accelerated Metal compute |
| Failed for 6 months | Proven technique (used by Moon Player) |

## Files Created

1. **`Stash/Features/VR/MetalVRRenderer.metal`** - Metal shaders for VR projection
   - Vertex shader: Transforms 3D sphere vertices
   - Fragment shader: Proper equirectangular→sphere UV mapping
   - Supports: SBS, OU, Fisheye, 180°, 360°

2. **`Stash/Features/VR/MetalVRRenderer.swift`** - Metal rendering engine
   - Extracts video frames from AVPlayer
   - Applies Metal shaders for projection
   - Handles video texture updates (60fps)

3. **`Stash/Features/VR/GVRStylePlayerView.swift`** - SwiftUI player view
   - Integrates Metal renderer with RealityKit immersive space
   - Gesture controls (drag, pinch, double-tap reset)
   - Format detection and switching

## Files Modified

1. **`Stash/StashApp.swift`** - Added new immersive space
   - Line 112-120: New `"GVRPlayerSpace"` immersive space

2. **`Stash/Features/VR/VRLibraryView.swift`** - Updated to use GVR player
   - Line 402: Changed from `"ImmersiveVideoSpace"` to `"GVRPlayerSpace"`

## How to Build & Test

### 1. Build the Project

```bash
# Open in Xcode
open Stash.xcodeproj

# Build for Vision Pro Simulator or Device
# Select: Product → Build (⌘B)
```

### 2. Expected Build Warnings

You may see warnings about:
- Metal shader validation (normal for custom shaders)
- visionOS API availability (handled with `#if os(visionOS)`)

### 3. Test the GVR Player

**Launch Sequence:**
1. Run app on Vision Pro (simulator or device)
2. Navigate to **VR Library** tab
3. Select any VR video
4. App will open the **GVR-Style Player** (Metal rendering)

**Expected Behavior:**
- ✅ Video loads and plays automatically
- ✅ Spherical projection visible around you
- ✅ Hand gestures work:
  - Drag horizontally → Rotate view
  - Drag vertically → Tilt view (±45°)
  - Pinch → Zoom (0.5x to 3x)
  - Double-tap Reset button → Recenter view
- ✅ Format switching via menu button
- ✅ Direct streaming preferred, HLS fallback for HEVC

**Debugging Output:**
```
🎬 GVR Player: Streaming from http://...
🎬 GVR Player: Detected format: SBS 180°
✅ Metal device created: Apple Vision Pro
✅ Metal pipeline state created
✅ Sphere geometry created: 4225 vertices
✅ GVR Player: Video playback started
```

### 4. Compare with Old Player (Optional)

To switch back to the old RealityKit player for comparison:

**Edit `VRLibraryView.swift` line 402:**
```swift
// New GVR player (Metal-based)
try await openImmersiveSpace(id: "GVRPlayerSpace")

// Old RealityKit player (for comparison)
try await openImmersiveSpace(id: "ImmersiveVideoSpace")
```

## Testing Checklist

### Format Detection
- [ ] **SBS 180°**: Side-by-side 180° video plays correctly
- [ ] **SBS 360°**: Side-by-side 360° video wraps around
- [ ] **OU 180°**: Over-under 180° video plays correctly
- [ ] **OU 360°**: Over-under 360° video wraps around
- [ ] **Fisheye 180°**: Fisheye distortion corrected
- [ ] **Fisheye 360°**: Fisheye 360° fully immersive

### Codec Support
- [ ] **H.264/MP4**: Direct streaming works (preferred)
- [ ] **HEVC/H.265**: Auto-fallback to HLS transcoding
- [ ] **WMV/VC-1**: HLS transcoding works

### Gesture Controls
- [ ] **Horizontal drag**: Smooth rotation left/right
- [ ] **Vertical drag**: Smooth tilt up/down (clamped ±45°)
- [ ] **Pinch zoom**: Zoom in/out (0.5x to 3x)
- [ ] **Reset button**: Returns to center/default zoom
- [ ] **Format menu**: Switches between SBS/OU/Fisheye

### Streaming Performance
- [ ] **VPN mode**: Detects VPN, uses Bearer token auth
- [ ] **Local mode**: Full codec detection, direct streaming
- [ ] **Network interruption**: Auto-reconnect works
- [ ] **Buffering**: Smooth playback, no stalls

## Known Limitations

1. **Metal Rendering**: Requires Metal-capable Vision Pro (all models supported)
2. **Direct Streaming**: Some server configurations may require HLS adjustment
3. **Fisheye Projection**: Complex distortion may need fine-tuning per video
4. **Frame Rate**: Limited to AVPlayer frame delivery (typically 30-60fps)

## Troubleshooting

### Black Screen
**Symptoms**: Immersive space opens, but video is black
**Fixes**:
1. Check console for Metal errors
2. Verify stream URL is accessible
3. Try HLS fallback (HEVC codec issue)

### Distorted Video
**Symptoms**: Video is warped or stretched incorrectly
**Fixes**:
1. Manually cycle format button (Menu → Format)
2. Check scene tags for correct format hints
3. Try different projection (180° vs 360°)

### Performance Issues
**Symptoms**: Stuttering, frame drops
**Fixes**:
1. Close other apps
2. Disable debug logging
3. Use direct streaming (not HLS)

### Console Debug Commands

```bash
# View Metal shader compilation
log show --predicate 'subsystem == "com.apple.metal"' --last 5m

# Monitor video playback
log show --predicate 'process == "Stash"' --style compact
```

## Reverting to Old Player

If you need to go back to the old RealityKit implementation:

1. **Edit `VRLibraryView.swift` line 402:**
   ```swift
   try await openImmersiveSpace(id: "ImmersiveVideoSpace")
   ```

2. **Rebuild and run**

## Next Steps

Once you confirm the GVR player works:

1. **Test with your actual VR library** (various codecs, formats)
2. **Report which formats work best** (SBS/OU/Fisheye)
3. **Identify any videos that don't play** (codec issues)
4. **Compare performance** (Metal vs old RealityKit)

## Technical Architecture

```
┌─────────────────────────────────────────┐
│ GVRStylePlayerView (SwiftUI)            │
│ - Gesture handling                      │
│ - UI controls                           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ MetalVRRenderer (Swift)                 │
│ - Video frame extraction (AVPlayer)     │
│ - Metal pipeline management             │
│ - Texture cache                         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ MetalVRRenderer.metal (Metal Shaders)   │
│ - Vertex shader (3D positioning)        │
│ - Fragment shader (UV projection)       │
│ - Equirectangular mapping               │
└─────────────────────────────────────────┘
```

## Support

If you encounter issues:

1. Check the console for error messages
2. Test with a known-working H.264 MP4 video
3. Compare Metal player vs old RealityKit player
4. Report specific codec/format combinations that fail

**Moon Player-style rendering should "just work" where the old approach failed!**
