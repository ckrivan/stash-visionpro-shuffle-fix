# VR Implementation Quick Reference

## Key File Locations

```
Stash/
├── Features/
│   ├── VR/
│   │   ├── VRLibraryView.swift ................. Browse & select VR content
│   │   ├── VRVideoView.swift .................. 2D fallback player
│   │   └── ImmersiveVideoScene.swift .......... PRIMARY immersive environment
│   ├── VRPlayer/
│   │   ├── Views/
│   │   │   ├── VRPlayerView.swift ............. XBVR immersive player (has DEBUG code)
│   │   │   ├── VideoControlsOverlay.swift ..... Playback controls
│   │   │   ├── VideoAdjustmentPanel.swift ..... Video filters (incomplete)
│   │   │   └── SpatialControlsView.swift ...... Spatial adjustments
│   │   ├── ViewModels/
│   │   │   └── VRPlayerViewModel.swift ........ State management
│   │   ├── Models/
│   │   │   ├── XBVRVideo.swift ............... Video metadata
│   │   │   ├── SpatialSettings.swift ......... Spatial config
│   │   │   └── VideoAdjustments.swift ........ Filter settings (incomplete)
│   │   └── Services/
│   │       └── XBVRService.swift ............. API service (incomplete)
│   └── Immersive/
│       ├── ImmersiveView.swift ............... Generic placeholder
│       └── ToggleImmersiveSpaceButton.swift .. Enter/exit immersive
├── Models/
│   └── AppModel.swift ........................ Central state store
└── StashApp.swift ........................... Main entry point
```

## VR Playback Flow

### Starting VR Playback
```
User taps VR scene in VRLibraryView
  ↓
Scene stored in appModel.currentScene
  ↓
openImmersiveSpace(id: "ImmersiveVideoSpace") called
  ↓
ImmersiveVideoScene initialized
  ↓
AVPlayer created with streaming URL
  ↓
VideoMaterial created from AVPlayer
  ↓
Curved mesh generated (SBS or OU format)
  ↓
Playback starts (after 500ms delay)
```

## Key Properties & States

### ImmersiveVideoScene State Variables
```swift
@State var videoPlayer: AVPlayer?           // Video playback engine
@State var videoMaterial: VideoMaterial?    // RealityKit material
@State var sphereEntity: ModelEntity?       // 3D surface entity
@State var vrFormat: VRFormat               // SBS, OU, or Mono
@State var sphereRadius: Float = 6.0        // Viewing distance (meters)
@State var bufferingProgress: Double = 0.0  // Buffered seconds
@State var isRecoveryInProgress: Bool       // Stall recovery active
```

### VRPlayerView Debug Code (NEEDS REMOVAL)
```swift
Line 22-26:  Color.blue.opacity(0.3) overlay
Line 263-270: Red test sphere at (0, 0, -2)
Line 277-278: Video entity hard-coded at (0, 0, -3)
```

## Format Detection

### Automatic Format Detection
```
Based on tags:
- Contains "sbs" / "side-by-side" / "lr" → Side-by-Side
- Contains "tb" / "over-under" / "topbottom" → Over-Under

Based on aspect ratio (if no tag match):
- ratio > 2.0 → Side-by-Side (e.g., 3840x1080 = 3.56)
- ratio < 1.0 → Over-Under (e.g., 1920x2160 = 0.89)
- 1.0 ≤ ratio ≤ 2.0 → Mono/Standard
```

## Playback Recovery Steps

### When Playback Stalls
1. **Detect**: No playback progress for 6+ seconds (3 checks × 2s)
2. **Step 1**: Resume playback (call player.play())
3. **Wait**: 1 second to see if that helped
4. **Step 2**: If still stalled, seek forward 1 second
5. **Wait**: 1 second for recovery
6. **Step 3**: If still stalled, reload player item with 20s buffer
7. **Reset**: Wait 3 seconds, clear recovery flag

## Video Streaming URLs

```
Direct Stream (VR Primary):
  /scene/{sceneID}/stream

HLS Stream (Fallback):
  /scene/{sceneID}/stream.m3u8

Headers Required:
  - ApiKey: [authentication]
  - Origin: [server address]
  - Referer: [server address]/scenes/[sceneID]
  - X-Playback-Session-Id: [UUID]
  - User-Agent: Mozilla/5.0...
  - Accept-Language: en-US,en;q=0.9
```

## Known Limitations

| Limitation | Impact | Notes |
|-----------|--------|-------|
| Video adjustments UI incomplete | Can't adjust brightness/contrast | Metal shaders referenced but not implemented |
| Dual VR systems | Confusing architecture | Both Stash (primary) and XBVR (secondary) exist |
| Settings not persistent | Settings lost on restart | UserDefaults code exists but may not work in immersive mode |
| Hard-coded recovery delays | May not work under all conditions | No adaptive timing based on network speed |
| Debug code in VRPlayerView | Visual artifacts if not removed | Colored overlays and test sphere visible in builds |

## Mesh Generation

### Curved Surface (Used for VR)
- **Segments**: 16 vertical, 32 horizontal (configurable)
- **Horizontal FOV**: 144° (π × 0.8 radians)
- **Vertical Range**: -0.6 to +0.6 (not full ±1.0 to reduce distortion)
- **Radius**: 6.0m (adjustable 4-10m via UI)

### UV Mapping
```swift
SideBySide:
  texU = (hIdx / hSegments) * 0.5      // Left half of texture
  texV = 1.0 - (vIdx / vSegments)

OverUnder:
  texU = (hIdx / hSegments)             // Full width
  texV = (1.0 - (vIdx / vSegments)) * 0.5  // Top half
```

## Important Code Snippets

### Creating AVPlayer for VR
```swift
let headers = [
  "X-Playback-Session-Id": UUID().uuidString,
  "ApiKey": apiKey,
  "Origin": serverAddress
]

let asset = AVURLAsset(url: url, options: [
  "AVURLAssetHTTPHeaderFieldsKey": headers
])

let playerItem = AVPlayerItem(asset: asset)
playerItem.preferredForwardBufferDuration = 10

let player = AVPlayer(playerItem: playerItem)
player.automaticallyWaitsToMinimizeStalling = false
```

### Creating VideoMaterial
```swift
videoMaterial = try VideoMaterial(avPlayer: videoPlayer)

// Then create mesh and entity:
let mesh = try MeshResource.generate(from: [meshDescriptor])
sphereEntity = ModelEntity(mesh: mesh, materials: [videoMaterial])
```

### Monitoring Playback
```swift
playerItem.publisher(for: \.status)        // Loading state
playerItem.publisher(for: \.isPlaybackBufferEmpty)  // Starvation
playerItem.publisher(for: \.loadedTimeRanges)      // Buffer progress
player.publisher(for: \.timeControlStatus) // Play/pause/buffering
```

## TODO Items (From Analysis)

### High Priority (Bugs)
- [ ] Remove debug code from VRPlayerView (lines 22-26, 263-270)
- [ ] Remove or consolidate backup/fix files
- [ ] Complete XBVRService implementation

### Medium Priority (Features)
- [ ] Implement video adjustment panel or remove UI
- [ ] Consolidate dual VR systems
- [ ] Test playback recovery under stress

### Low Priority (Polish)
- [ ] Add settings persistence across sessions
- [ ] Implement custom Metal shaders for adjustments
- [ ] Add telemetry/analytics

## Testing Checklist

- [ ] VR content loads without crashing
- [ ] Format detection works (test SBS and OU content)
- [ ] Playback recovers from stalls
- [ ] Gesture controls responsive (drag, tap)
- [ ] Audio/video sync maintained
- [ ] Memory cleanup after exit
- [ ] Settings survive app backgrounding
- [ ] Works with various VPN configurations

