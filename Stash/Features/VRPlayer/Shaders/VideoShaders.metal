#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
    float3 normal;
    float3 worldPosition;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 normalMatrix;
};

vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    VertexOut out;
    
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPosition.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.texCoords = in.texCoords;
    out.normal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    
    return out;
}

// MARK: - Video Adjustment Parameters

struct VideoAdjustments {
    float brightness;    // -1.0 to 1.0
    float contrast;      // 0.0 to 2.0
    float saturation;    // 0.0 to 2.0
    float sharpness;     // 0.0 to 2.0
    float colorTemp;     // -1.0 to 1.0
    float gamma;         // 0.5 to 2.0
    float hue;           // -π to π (radians)
    float vibrance;      // -1.0 to 1.0
};

// MARK: - Color Space Conversion Functions

float3 rgb_to_hsv(float3 rgb) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(rgb.bg, K.wz), float4(rgb.gb, K.xy), step(rgb.b, rgb.g));
    float4 q = mix(float4(p.xyw, rgb.r), float4(rgb.r, p.yzx), step(p.x, rgb.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv_to_rgb(float3 hsv) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
    return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

// MARK: - Video Processing Functions

float3 apply_brightness_contrast(float3 color, float brightness, float contrast) {
    // Apply brightness
    color += brightness;
    
    // Apply contrast around midpoint
    color = ((color - 0.5) * contrast) + 0.5;
    
    return clamp(color, 0.0, 1.0);
}

float3 apply_saturation(float3 color, float saturation) {
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    return mix(float3(luminance), color, saturation);
}

float3 apply_vibrance(float3 color, float vibrance) {
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    float mask = clamp(1.0 - luminance, 0.0, 1.0);
    return mix(color, apply_saturation(color, 1.0 + vibrance), mask);
}

float3 apply_color_temperature(float3 color, float temp) {
    // Simple color temperature adjustment
    float3 warm = float3(1.0, 0.9, 0.8);
    float3 cool = float3(0.8, 0.9, 1.0);
    
    if (temp > 0.0) {
        return color * mix(float3(1.0), cool, temp);
    } else {
        return color * mix(float3(1.0), warm, -temp);
    }
}

float3 apply_gamma(float3 color, float gamma) {
    return pow(max(color, 0.0), float3(1.0 / gamma));
}

float3 apply_hue_shift(float3 color, float hue_shift) {
    float3 hsv = rgb_to_hsv(color);
    hsv.x = fract(hsv.x + hue_shift / (2.0 * M_PI_F));
    return hsv_to_rgb(hsv);
}

// MARK: - Sharpening Filter

float3 apply_sharpening(texture2d<float> tex, sampler s, float2 texCoords, float sharpness) {
    if (sharpness <= 1.0) {
        return tex.sample(s, texCoords).rgb;
    }
    
    float2 texelSize = 1.0 / float2(tex.get_width(), tex.get_height());
    
    // Sample center and surrounding pixels
    float3 center = tex.sample(s, texCoords).rgb;
    float3 up = tex.sample(s, texCoords + float2(0.0, -texelSize.y)).rgb;
    float3 down = tex.sample(s, texCoords + float2(0.0, texelSize.y)).rgb;
    float3 left = tex.sample(s, texCoords + float2(-texelSize.x, 0.0)).rgb;
    float3 right = tex.sample(s, texCoords + float2(texelSize.x, 0.0)).rgb;
    
    // Calculate sharpening kernel
    float3 edge = (up + down + left + right) * 0.25;
    float3 sharpened = center + (center - edge) * (sharpness - 1.0);
    
    return clamp(sharpened, 0.0, 1.0);
}

// MARK: - Fragment Shaders

// Basic video fragment shader without adjustments
fragment float4 fragment_video_basic(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return videoTexture.sample(s, in.texCoords);
}

// Advanced video fragment shader with full adjustments
fragment float4 fragment_video_adjusted(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    constant VideoAdjustments& adj [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Sample base color with optional sharpening
    float3 color;
    if (adj.sharpness > 1.01) {
        color = apply_sharpening(videoTexture, s, in.texCoords, adj.sharpness);
    } else {
        color = videoTexture.sample(s, in.texCoords).rgb;
    }
    
    // Apply gamma correction first (affects all other adjustments)
    if (abs(adj.gamma - 1.0) > 0.01) {
        color = apply_gamma(color, adj.gamma);
    }
    
    // Apply brightness and contrast
    if (abs(adj.brightness) > 0.01 || abs(adj.contrast - 1.0) > 0.01) {
        color = apply_brightness_contrast(color, adj.brightness, adj.contrast);
    }
    
    // Apply hue shift
    if (abs(adj.hue) > 0.01) {
        color = apply_hue_shift(color, adj.hue);
    }
    
    // Apply saturation
    if (abs(adj.saturation - 1.0) > 0.01) {
        color = apply_saturation(color, adj.saturation);
    }
    
    // Apply vibrance (after saturation)
    if (abs(adj.vibrance) > 0.01) {
        color = apply_vibrance(color, adj.vibrance);
    }
    
    // Apply color temperature
    if (abs(adj.colorTemp) > 0.01) {
        color = apply_color_temperature(color, adj.colorTemp);
    }
    
    return float4(color, 1.0);
}

// Side-by-side stereo fragment shader (left eye)
fragment float4 fragment_sbs_left(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    constant VideoAdjustments& adj [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Map to left half of texture
    float2 texCoords = float2(in.texCoords.x * 0.5, in.texCoords.y);
    
    // Sample and apply adjustments
    float3 color;
    if (adj.sharpness > 1.01) {
        color = apply_sharpening(videoTexture, s, texCoords, adj.sharpness);
    } else {
        color = videoTexture.sample(s, texCoords).rgb;
    }
    
    // Apply all adjustments (same as basic adjusted shader)
    if (abs(adj.gamma - 1.0) > 0.01) {
        color = apply_gamma(color, adj.gamma);
    }
    if (abs(adj.brightness) > 0.01 || abs(adj.contrast - 1.0) > 0.01) {
        color = apply_brightness_contrast(color, adj.brightness, adj.contrast);
    }
    if (abs(adj.hue) > 0.01) {
        color = apply_hue_shift(color, adj.hue);
    }
    if (abs(adj.saturation - 1.0) > 0.01) {
        color = apply_saturation(color, adj.saturation);
    }
    if (abs(adj.vibrance) > 0.01) {
        color = apply_vibrance(color, adj.vibrance);
    }
    if (abs(adj.colorTemp) > 0.01) {
        color = apply_color_temperature(color, adj.colorTemp);
    }
    
    return float4(color, 1.0);
}

// Side-by-side stereo fragment shader (right eye)
fragment float4 fragment_sbs_right(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    constant VideoAdjustments& adj [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Map to right half of texture
    float2 texCoords = float2(in.texCoords.x * 0.5 + 0.5, in.texCoords.y);
    
    // Apply same processing as left eye
    float3 color;
    if (adj.sharpness > 1.01) {
        color = apply_sharpening(videoTexture, s, texCoords, adj.sharpness);
    } else {
        color = videoTexture.sample(s, texCoords).rgb;
    }
    
    if (abs(adj.gamma - 1.0) > 0.01) {
        color = apply_gamma(color, adj.gamma);
    }
    if (abs(adj.brightness) > 0.01 || abs(adj.contrast - 1.0) > 0.01) {
        color = apply_brightness_contrast(color, adj.brightness, adj.contrast);
    }
    if (abs(adj.hue) > 0.01) {
        color = apply_hue_shift(color, adj.hue);
    }
    if (abs(adj.saturation - 1.0) > 0.01) {
        color = apply_saturation(color, adj.saturation);
    }
    if (abs(adj.vibrance) > 0.01) {
        color = apply_vibrance(color, adj.vibrance);
    }
    if (abs(adj.colorTemp) > 0.01) {
        color = apply_color_temperature(color, adj.colorTemp);
    }
    
    return float4(color, 1.0);
}

// Over-under stereo fragment shader (top eye)
fragment float4 fragment_ou_top(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    constant VideoAdjustments& adj [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Map to top half of texture
    float2 texCoords = float2(in.texCoords.x, in.texCoords.y * 0.5);
    
    // Apply same processing as other shaders
    float3 color;
    if (adj.sharpness > 1.01) {
        color = apply_sharpening(videoTexture, s, texCoords, adj.sharpness);
    } else {
        color = videoTexture.sample(s, texCoords).rgb;
    }
    
    if (abs(adj.gamma - 1.0) > 0.01) {
        color = apply_gamma(color, adj.gamma);
    }
    if (abs(adj.brightness) > 0.01 || abs(adj.contrast - 1.0) > 0.01) {
        color = apply_brightness_contrast(color, adj.brightness, adj.contrast);
    }
    if (abs(adj.hue) > 0.01) {
        color = apply_hue_shift(color, adj.hue);
    }
    if (abs(adj.saturation - 1.0) > 0.01) {
        color = apply_saturation(color, adj.saturation);
    }
    if (abs(adj.vibrance) > 0.01) {
        color = apply_vibrance(color, adj.vibrance);
    }
    if (abs(adj.colorTemp) > 0.01) {
        color = apply_color_temperature(color, adj.colorTemp);
    }
    
    return float4(color, 1.0);
}

// Over-under stereo fragment shader (bottom eye)
fragment float4 fragment_ou_bottom(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    constant VideoAdjustments& adj [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Map to bottom half of texture
    float2 texCoords = float2(in.texCoords.x, in.texCoords.y * 0.5 + 0.5);
    
    // Apply same processing as other shaders
    float3 color;
    if (adj.sharpness > 1.01) {
        color = apply_sharpening(videoTexture, s, texCoords, adj.sharpness);
    } else {
        color = videoTexture.sample(s, texCoords).rgb;
    }
    
    if (abs(adj.gamma - 1.0) > 0.01) {
        color = apply_gamma(color, adj.gamma);
    }
    if (abs(adj.brightness) > 0.01 || abs(adj.contrast - 1.0) > 0.01) {
        color = apply_brightness_contrast(color, adj.brightness, adj.contrast);
    }
    if (abs(adj.hue) > 0.01) {
        color = apply_hue_shift(color, adj.hue);
    }
    if (abs(adj.saturation - 1.0) > 0.01) {
        color = apply_saturation(color, adj.saturation);
    }
    if (abs(adj.vibrance) > 0.01) {
        color = apply_vibrance(color, adj.vibrance);
    }
    if (abs(adj.colorTemp) > 0.01) {
        color = apply_color_temperature(color, adj.colorTemp);
    }
    
    return float4(color, 1.0);
}