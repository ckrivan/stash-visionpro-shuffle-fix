# VR Video Player Implementation Guide for Vision Pro

## Overview
This guide provides comprehensive instructions for implementing a VR video player section within an existing Vision Pro app that uses Stash, with XBVR integration for 180° and 360° video playback.

## Core Requirements

### Video Format Support
- **180° Stereoscopic Videos**: Side-by-side (SBS) and Over-Under (OU) formats
- **360° Spherical Videos**: Equirectangular projection support
- **Video Codecs**: H.264, H.265/HEVC, AV1 (if supported)
- **Resolution Support**: Up to 8K per eye for optimal Vision Pro experience

### Video Controls
1. **Playback Controls**
   - Play/Pause toggle
   - Forward skip: 60 seconds
   - Backward skip: 30 seconds
   - Playhead with current time display
   - Scrubber for precise navigation

2. **Video Adjustments**
   - Color temperature adjustment
   - Saturation: -100% to +100%
   - Brightness: -100% to +100%
   - Sharpness: 0% to +200%
   - Contrast: -100% to +100%

3. **Spatial Controls**
   - Tilt: ±45° on X and Y axes
   - Zoom: 0.5x to 2.0x
   - Rotate: 360° on all axes
   - Reset view button
## Architecture Overview

### Component Structure
```
VRPlayerSection/
├── Models/
│   ├── VRVideoModel.swift
│   ├── VideoAdjustments.swift
│   └── XBVRIntegration.swift
├── Views/
│   ├── VRPlayerView.swift
│   ├── VideoControlsOverlay.swift
│   ├── AdjustmentPanel.swift
│   └── SpatialControlsView.swift
├── ViewModels/
│   ├── VRPlayerViewModel.swift
│   └── VideoProcessingViewModel.swift
├── Services/
│   ├── XBVRService.swift
│   ├── VideoRenderer.swift
│   └── SpatialTrackingService.swift
└── Utilities/
    ├── VideoFormats.swift
    └── MetalShaders.metal
```

### Integration Points
1. **Stash Integration**: Maintain existing Stash functionality while adding VR section
2. **XBVR API**: Connect to XBVR server for video metadata and streaming
3. **RealityKit/Metal**: Hardware-accelerated video rendering
4. **ARKit**: Head tracking and spatial positioning