//
//  MetalVRRenderer.metal
//  Stash VR Player - Metal Shaders for Equirectangular Projection
//
//  This implements Moon Player-style VR video rendering using Metal shaders.
//  Supports: SBS/OU/Fisheye, 180°/360°, proper UV mapping for all formats.
//

#include <metal_stdlib>
using namespace metal;

// Vertex input/output structures
struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPosition;
};

// Uniforms for VR rendering
struct VRUniforms {
    float4x4 modelViewProjection;
    float4x4 modelMatrix;
    int videoFormat;  // 0=Mono, 1=SBS, 2=OU, 3=Fisheye
    int projectionType; // 0=180°, 1=360°
    float zoom;
    float rotation;
    float tilt;
};

// Video format constants
constant int FORMAT_MONO = 0;
constant int FORMAT_SBS = 1;
constant int FORMAT_OU = 2;
constant int FORMAT_FISHEYE = 3;

constant int PROJECTION_180 = 0;
constant int PROJECTION_360 = 1;

// Vertex shader - transforms vertices from model space to clip space
vertex VertexOut vrVertexShader(VertexIn in [[stage_in]],
                                constant VRUniforms &uniforms [[buffer(1)]]) {
    VertexOut out;

    // Transform position to clip space
    out.position = uniforms.modelViewProjection * float4(in.position, 1.0);

    // Pass through texture coordinates (will be modified in fragment shader)
    out.texCoord = in.texCoord;

    // Transform to world space for proper projection
    out.worldPosition = (uniforms.modelMatrix * float4(in.position, 1.0)).xyz;

    return out;
}

// Helper: Convert 3D position to spherical coordinates
float2 cartesianToSpherical(float3 position) {
    // Normalize the position
    float3 dir = normalize(position);

    // Calculate spherical coordinates
    float theta = atan2(dir.x, -dir.z);  // Horizontal angle
    float phi = asin(dir.y);             // Vertical angle

    return float2(theta, phi);
}

// Helper: Apply fisheye distortion correction
float2 applyFisheyeProjection(float2 uv, float fov) {
    // Center the UV coordinates
    float2 centered = uv - 0.5;

    // Calculate radial distance from center
    float r = length(centered);
    float theta = atan2(centered.y, centered.x);

    // Apply equidistant projection (fisheye correction)
    // r = θ * radius / fov
    float correctedR = r * fov / (M_PI_F * 0.5);

    // Convert back to UV coordinates
    float2 corrected = float2(
        0.5 + correctedR * cos(theta),
        0.5 + correctedR * sin(theta)
    );

    return corrected;
}

// Fragment shader - samples video texture with proper VR projection
fragment float4 vrFragmentShader(VertexOut in [[stage_in]],
                                 texture2d<float> videoTexture [[texture(0)]],
                                 constant VRUniforms &uniforms [[buffer(1)]]) {

    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);

    // Convert world position to spherical coordinates
    float2 spherical = cartesianToSpherical(in.worldPosition);
    float theta = spherical.x;  // Horizontal angle (-π to π)
    float phi = spherical.y;    // Vertical angle (-π/2 to π/2)

    // Apply rotation and tilt from user gestures
    theta += uniforms.rotation;
    phi += uniforms.tilt;

    // Clamp vertical angle to prevent over-rotation
    phi = clamp(phi, -M_PI_F / 2.0, M_PI_F / 2.0);

    // Calculate base UV coordinates for equirectangular projection
    float u, v;

    if (uniforms.projectionType == PROJECTION_360) {
        // 360° projection: Full horizontal wrap (0 to 2π)
        u = (theta / (2.0 * M_PI_F)) + 0.5;
    } else {
        // 180° projection: Limited horizontal range (-π/2 to π/2)
        u = (theta / M_PI_F) + 0.5;
    }

    // Vertical coordinate (same for 180° and 360°)
    v = 1.0 - ((phi / M_PI_F) + 0.5);

    // Apply format-specific UV adjustments
    float2 finalUV;

    switch (uniforms.videoFormat) {
        case FORMAT_SBS:
            // Side-by-side: Use left half of texture
            finalUV = float2(u * 0.5, v);
            break;

        case FORMAT_OU:
            // Over-under: Use top half of texture
            finalUV = float2(u, v * 0.5);
            break;

        case FORMAT_FISHEYE: {
            // Fisheye: Apply distortion correction
            float fov = (uniforms.projectionType == PROJECTION_360) ? M_PI_F : (M_PI_F * 0.5);
            float2 fisheyeUV = applyFisheyeProjection(float2(u, v), fov);

            // Adjust for stereo format
            if (uniforms.videoFormat == FORMAT_SBS) {
                finalUV = float2(fisheyeUV.x * 0.5, fisheyeUV.y);
            } else {
                finalUV = fisheyeUV;
            }
            break;
        }

        case FORMAT_MONO:
        default:
            // Mono: Use full texture
            finalUV = float2(u, v);
            break;
    }

    // Apply zoom (scale UV from center)
    float2 centeredUV = finalUV - 0.5;
    centeredUV /= uniforms.zoom;
    finalUV = centeredUV + 0.5;

    // Clamp UV to valid range
    finalUV = clamp(finalUV, 0.0, 1.0);

    // Sample the video texture
    float4 color = videoTexture.sample(textureSampler, finalUV);

    return color;
}

// Simplified shader for flat 2D video (non-VR content)
fragment float4 flatFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> videoTexture [[texture(0)]]) {

    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    return videoTexture.sample(textureSampler, in.texCoord);
}
