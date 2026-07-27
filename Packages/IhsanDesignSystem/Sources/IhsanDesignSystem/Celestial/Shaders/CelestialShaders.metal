// CelestialShaders.metal — Inferno-style single-purpose SwiftUI shaders
// for the celestial plate.
//
// ⚠️ CURRENTLY EXCLUDED FROM THE BUILD (see Package.swift `exclude:`).
//
// The build machine could not install the Xcode Metal Toolchain
// component (`xcodebuild -downloadComponent MetalToolchain` fails at
// Apple's catalog server), and an unconditionally compiled .metal file
// would break every app build until the component installs. The
// SwiftUI implementations in `LuminousBody` and `PlateGrainOverlay`
// are the exact static fallbacks for these two functions and remain
// the Reduce Transparency / watchOS paths permanently.
//
// To enable once the toolchain is available:
//   1. `xcodebuild -downloadComponent MetalToolchain`
//   2. In Package.swift, replace the `exclude:` entry with
//      `resources: [.process("Celestial/Shaders/CelestialShaders.metal")]`.
//   3. Route `LuminousBody`'s halo through
//      `.colorEffect(ShaderLibrary.bundle(.module).luminousHalo(...))`
//      and `PlateGrainOverlay` through
//      `.colorEffect(ShaderLibrary.bundle(.module).celestialGrain(...))`,
//      keeping the current views as the accessibility fallbacks.

#include <metal_stdlib>
using namespace metal;

/// Exponential-falloff halo. Apply as a colorEffect to a solid-fill
/// circle sized to the halo's outer diameter; the shader shapes the
/// alpha into a light-like falloff no gradient-stop approximation
/// matches.
[[ stitchable ]] half4 luminousHalo(
    float2 position,
    half4 color,
    float2 size,
    float coreRadius,
    float strength
) {
    float2 center = size * 0.5;
    float d = distance(position, center);
    float normalized = max(0.0, (d - coreRadius) / max(size.x * 0.5 - coreRadius, 1.0));
    float falloff = exp(-normalized * normalized * 4.5) * strength;
    return half4(color.rgb, color.a * half(falloff));
}

/// Filmic grain: a per-pixel hash modulated by a time step quantized
/// to 12 fps for a filmic cadence. Pass `time = 0` under Reduce
/// Motion for fully static grain. Intensity is expected ≤ 0.03.
[[ stitchable ]] half4 celestialGrain(
    float2 position,
    half4 color,
    float intensity,
    float time
) {
    float frame = floor(time * 12.0);
    float n = fract(sin(dot(position + frame, float2(12.9898, 78.233))) * 43758.5453);
    half g = half((n - 0.5) * 2.0 * min(intensity, 0.03));
    return half4(clamp(color.rgb + half3(g, g, g), half3(0.0h), half3(1.0h)), color.a);
}
