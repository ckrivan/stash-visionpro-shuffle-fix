# Video Rendering Implementation

## Core Rendering Pipeline

### 1. Video Decoder Setup
```swift
class VRVideoDecoder {
    private var assetReader: AVAssetReader?
    private var videoOutput: AVAssetReaderTrackOutput?
    private var displayLink: CADisplayLink?
    
    func setupDecoder(for url: URL) {
        // Configure AVAssetReader for optimal performance
        // Set up pixel buffer attributes for Metal compatibility
    }
}
```

### 2. Sphere Geometry Creation
```swift
class SphereMesh {
    func create360Sphere(radius: Float = 10.0) -> MDLMesh {
        // Create UV-mapped sphere for 360° content
        // Invert normals for interior viewing
    }
    
    func create180Hemisphere(radius: Float = 10.0) -> MDLMesh {
        // Create hemisphere for 180° content
        // Optimize vertex count for performance
    }
}
```

### 3. Metal Shader Pipeline
```metal
// Vertex shader for sphere projection
vertex VertexOut sphereVertex(VertexIn in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    // Transform vertices based on view adjustments
    // Apply tilt, zoom, and rotation matrices
}
```
// Fragment shader for video adjustments
fragment float4 videoFragment(VertexOut in [[stage_in]],
                             texture2d<float> videoTexture [[texture(0)]],
                             constant VideoAdjustments &adjustments [[buffer(0)]]) {
    // Sample video texture
    float4 color = videoTexture.sample(sampler, in.texCoords);
    
    // Apply brightness
    color.rgb += adjustments.brightness;
    
    // Apply contrast
    color.rgb = ((color.rgb - 0.5) * adjustments.contrast) + 0.5;
    
    // Apply saturation
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(gray), color.rgb, adjustments.saturation);
    
    // Apply sharpness (simplified unsharp mask)
    // Apply color temperature adjustments
    
    return color;
}
```

### 4. Stereoscopic Processing
```swift
class StereoProcessor {
    func processFrame(_ pixelBuffer: CVPixelBuffer, mode: StereoMode) -> (left: CVPixelBuffer, right: CVPixelBuffer) {
        switch mode {
        case .sideBySide:
            // Split horizontal halves
        case .overUnder:
            // Split vertical halves
        case .mono:
            // Duplicate for both eyes
        }
    }
}
```