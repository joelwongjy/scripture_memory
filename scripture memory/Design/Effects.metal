//
//  Effects.metal
//  Scripture Memory
//
//  The two shader effects of the Illuminated design language (docs/DESIGN.md):
//  paper grain for parchment cards, and the gilt sheen for gold moments.
//  Both are SwiftUI `colorEffect` shaders (iOS 17+).
//

#include <metal_stdlib>
using namespace metal;

/// Cheap 2D hash → 0…1. Good enough for static grain; not for anything animated.
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Parchment tooth: two scales of value noise nudging luminance by
/// ±`strength`. Scaled by alpha so antialiased card edges stay clean.
[[ stitchable ]] half4 paperGrain(float2 position, half4 color, float strength) {
    if (color.a <= 0.001h) { return color; }
    float fine   = hash21(floor(position * 1.7));
    float coarse = hash21(floor(position * 0.33) + 7.7);
    float n = (fine * 0.6 + coarse * 0.4) - 0.5;
    half  shift = half(n * strength) * color.a;
    return half4(color.rgb + half3(shift), color.a);
}

/// A soft diagonal band of light sweeping across the view every few seconds —
/// the glint you get tilting gold leaf. `sheenColor.a` is the peak strength.
[[ stitchable ]] half4 giltSheen(float2 position, half4 color,
                                 float2 size, float time, half4 sheenColor) {
    if (color.a <= 0.001h) { return color; }
    const float period = 3.4;   // seconds per sweep
    float t = fract(time / period);
    // Position along the top-left → bottom-right diagonal, 0…1.
    float d = (position.x + position.y) / max(size.x + size.y, 1.0);
    // Band centre travels beyond both ends so the sheen fully enters and exits,
    // with a rest between sweeps.
    float centre = mix(-0.5, 1.5, t);
    float band = exp(-pow((d - centre) / 0.09, 2.0));
    half  amount = half(band) * sheenColor.a * color.a;
    return half4(mix(color.rgb, sheenColor.rgb, amount), color.a);
}
