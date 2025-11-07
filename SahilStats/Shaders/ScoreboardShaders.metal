//
//  ScoreboardShaders.metal
//  SahilStats
//
//  Custom Metal shaders for scoreboard visual effects
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Gradient Background Shader

kernel void gradientBackground(
    texture2d<float, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());

    // Vertical gradient from dark to darker
    float3 topColor = float3(0.15, 0.15, 0.15);
    float3 bottomColor = float3(0.05, 0.05, 0.05);
    float3 color = mix(bottomColor, topColor, uv.y);

    // Add slight blue tint for modern look
    color += float3(0.0, 0.02, 0.05);

    outTexture.write(float4(color, 0.92), gid);
}

// MARK: - Glow Effect Shader

kernel void glowEffect(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float &intensity [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = inTexture.read(gid);

    // Sample surrounding pixels for glow
    float2 texSize = float2(inTexture.get_width(), inTexture.get_height());
    float4 glow = float4(0.0);
    int radius = 3;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            int2 offset = int2(x, y);
            uint2 samplePos = uint2(int2(gid) + offset);

            // Bounds check
            if (samplePos.x < texSize.x && samplePos.y < texSize.y) {
                float4 sample = inTexture.read(samplePos);
                float distance = length(float2(x, y)) / float(radius);
                float weight = 1.0 - distance;
                glow += sample * weight;
            }
        }
    }

    glow /= float((radius * 2 + 1) * (radius * 2 + 1));
    glow *= intensity;

    // Blend original with glow
    float4 result = color + glow * 0.5;
    outTexture.write(result, gid);
}

// MARK: - Team Color Tint Shader

kernel void teamColorTint(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float3 &homeColor [[buffer(0)]],
    constant float3 &awayColor [[buffer(1)]],
    constant float &tintStrength [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = inTexture.read(gid);
    float2 uv = float2(gid) / float2(inTexture.get_width(), inTexture.get_height());

    // Apply home team color tint on left, away on right
    float3 tintColor = mix(homeColor, awayColor, smoothstep(0.3, 0.7, uv.x));

    // Blend tint with original, preserving alpha
    float3 tinted = mix(color.rgb, tintColor, tintStrength * 0.2);
    outTexture.write(float4(tinted, color.a), gid);
}

// MARK: - Smooth Shadow Shader

kernel void smoothShadow(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float2 &shadowOffset [[buffer(0)]],
    constant float &shadowRadius [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = inTexture.read(gid);

    // Create soft shadow
    float shadow = 0.0;
    int samples = 8;

    for (int i = 0; i < samples; i++) {
        float angle = float(i) / float(samples) * 2.0 * M_PI_F;
        float2 offset = shadowOffset + shadowRadius * float2(cos(angle), sin(angle));
        uint2 samplePos = uint2(int2(gid) + int2(offset));

        if (samplePos.x < uint(inTexture.get_width()) && samplePos.y < uint(inTexture.get_height())) {
            shadow += inTexture.read(samplePos).a;
        }
    }

    shadow /= float(samples);

    // Composite shadow with original
    float4 shadowColor = float4(0.0, 0.0, 0.0, shadow * 0.7);
    float4 result = mix(shadowColor, color, color.a);

    outTexture.write(result, gid);
}

// MARK: - Frosted Glass Blur

kernel void frostedGlassBlur(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float &blurRadius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    int radius = int(blurRadius);

    // Gaussian blur
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            int2 offset = int2(x, y);
            uint2 samplePos = uint2(int2(gid) + offset);

            if (samplePos.x < uint(inTexture.get_width()) && samplePos.y < uint(inTexture.get_height())) {
                float distance = length(float2(x, y));
                float weight = exp(-distance * distance / (2.0 * blurRadius * blurRadius));
                color += inTexture.read(samplePos) * weight;
                totalWeight += weight;
            }
        }
    }

    color /= totalWeight;

    // Add slight brightness to frosted glass
    color.rgb *= 1.1;

    outTexture.write(color, gid);
}

// MARK: - Composite Scoreboard onto Video

kernel void compositeScoreboard(
    texture2d<float, access::read> videoTexture [[texture(0)]],
    texture2d<float, access::read> scoreboardTexture [[texture(1)]],
    texture2d<float, access::write> outTexture [[texture(2)]],
    constant float2 &position [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 videoColor = videoTexture.read(gid);

    // Calculate scoreboard texture coordinate
    int2 scoreboardPos = int2(gid) - int2(position);

    if (scoreboardPos.x >= 0 && scoreboardPos.x < int(scoreboardTexture.get_width()) &&
        scoreboardPos.y >= 0 && scoreboardPos.y < int(scoreboardTexture.get_height())) {

        float4 scoreboardColor = scoreboardTexture.read(uint2(scoreboardPos));

        // Alpha blend scoreboard over video
        float alpha = scoreboardColor.a;
        float4 result = videoColor * (1.0 - alpha) + scoreboardColor * alpha;
        outTexture.write(result, gid);
    } else {
        outTexture.write(videoColor, gid);
    }
}
