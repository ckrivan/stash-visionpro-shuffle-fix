# XBVR Integration Specification

## API Integration

### Authentication
```swift
struct XBVRConfig {
    let baseURL: String
    let apiKey: String?
    let username: String?
    let password: String?
}
```

### Endpoints to Implement

1. **Get Video List**
   - Endpoint: `GET /api/videos`
   - Parameters: `limit`, `offset`, `sort`, `filter`
   - Returns: Array of video metadata

2. **Get Video Details**
   - Endpoint: `GET /api/videos/{id}`
   - Returns: Complete video information including:
     - Title, duration, resolution
     - Video type (180°/360°)
     - Stereo mode (SBS/OU/Mono)
     - File path/streaming URL

3. **Stream Video**
   - Endpoint: `GET /api/videos/{id}/stream`
   - Supports: Range requests for seeking
   - Returns: Video stream with proper headers

4. **Get Thumbnails**
   - Endpoint: `GET /api/videos/{id}/thumbnails`
   - Returns: Preview images for scrubber

### Data Models

```swift
struct XBVRVideo {
    let id: String
    let title: String
    let duration: TimeInterval
    let resolution: CGSize
    let videoType: VideoType
    let stereoMode: StereoMode
    let streamURL: URL
    let thumbnailURL: URL?
    
    enum VideoType {
        case flat
        case vr180
        case vr360
    }
    
    enum StereoMode {
        case mono
        case sideBySide
        case overUnder
    }
}
```