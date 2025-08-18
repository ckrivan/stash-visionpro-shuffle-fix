# UI Components Specification

## Main VR Player View

### Layout Structure
```swift
struct VRPlayerView: View {
    @StateObject private var viewModel = VRPlayerViewModel()
    @State private var showControls = true
    @State private var showAdjustments = false
    
    var body: some View {
        RealityView { content in
            // Setup 360/180 sphere entity
            // Attach video material
        }
        .overlay(alignment: .bottom) {
            if showControls {
                VideoControlsOverlay()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            if showAdjustments {
                AdjustmentPanel()
                    .transition(.slide)
            }
        }
        .gesture(spatialTapGesture)
        .onAppear { viewModel.loadVideo() }
    }
}
```

## Control Components

### 1. Video Controls Overlay
```swift
struct VideoControlsOverlay: View {
    var body: some View {
        VStack(spacing: 20) {
            // Time labels and scrubber
            HStack {
                Text(currentTime)
                VideoScrubber()
                Text(duration)
            }
            
            // Playback controls
            HStack(spacing: 40) {
                Button(action: backward30) {
                    Image(systemName: "gobackward.30")
                }
                
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: forward60) {
                    Image(systemName: "goforward.60")
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(20)
    }
}
```
### 2. Adjustment Panel
```swift
struct AdjustmentPanel: View {
    @EnvironmentObject var adjustments: VideoAdjustments
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Video Adjustments")
                .font(.headline)
            
            // Color Temperature
            AdjustmentSlider(
                value: $adjustments.colorTemperature,
                range: -1...1,
                label: "Color",
                icon: "thermometer"
            )
            
            // Saturation
            AdjustmentSlider(
                value: $adjustments.saturation,
                range: 0...2,
                label: "Saturation",
                icon: "drop.fill"
            )
            
            // Brightness
            AdjustmentSlider(
                value: $adjustments.brightness,
                range: -1...1,
                label: "Brightness",
                icon: "sun.max.fill"
            )
            
            // Sharpness
            AdjustmentSlider(
                value: $adjustments.sharpness,
                range: 0...2,
                label: "Sharpness",
                icon: "circle.grid.3x3.fill"
            )
            
            // Contrast
            AdjustmentSlider(
                value: $adjustments.contrast,
                range: 0...2,
                label: "Contrast",
                icon: "circle.lefthalf.filled"
            )
            
            Divider()
            
            Button("Reset All") {
                adjustments.reset()
            }
        }
        .padding()
        .frame(width: 300)
        .background(.regularMaterial)
        .cornerRadius(20)
    }
}
```
### 3. Spatial Controls
```swift
struct SpatialControlsView: View {
    @EnvironmentObject var spatialSettings: SpatialSettings
    
    var body: some View {
        VStack(spacing: 20) {
            // Tilt Controls
            HStack {
                Text("Tilt")
                Spacer()
                Button("Reset") {
                    spatialSettings.resetTilt()
                }
            }
            
            HStack {
                Image(systemName: "arrow.up.and.down")
                Slider(value: $spatialSettings.tiltX, in: -45...45)
                Text("\(Int(spatialSettings.tiltX))°")
            }
            
            HStack {
                Image(systemName: "arrow.left.and.right")
                Slider(value: $spatialSettings.tiltY, in: -45...45)
                Text("\(Int(spatialSettings.tiltY))°")
            }
            
            // Zoom Control
            HStack {
                Image(systemName: "magnifyingglass")
                Slider(value: $spatialSettings.zoom, in: 0.5...2.0)
                Text("\(Int(spatialSettings.zoom * 100))%")
            }
            
            // Rotation Control
            HStack {
                Image(systemName: "rotate.3d")
                Slider(value: $spatialSettings.rotation, in: 0...360)
                Text("\(Int(spatialSettings.rotation))°")
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(15)
    }
}
```