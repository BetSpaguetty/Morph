#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

inline float morphCellHash(float2 cell, float seed) {
    float n = dot(cell, float2(127.1, 311.7)) + seed * 19.19;
    return fract(sin(n) * 43758.5453123);
}

/// Shader GPU único de erosão / granulação para `Fade Granulado`, `Desintegração` e `Corroído`.
/// Substitui múltiplos `Canvas` CPU + `.destinationOut` + `.compositingGroup()` por 1 passe leve.
[[ stitchable ]] half4 morphErosionEffect(
    float2 position,
    half4 color,
    float2 boundsSize,
    float cellSize,
    float threshold,
    float timeTick,
    float verticalBias,
    float minAlphaFloor
) {
    if (color.a <= 0.001h || threshold <= 0.001) {
        return color;
    }

    float safeCell = max(cellSize, 4.0);
    float2 cell = floor(position / safeCell);
    float rnd = morphCellHash(cell, timeTick);

    float h = max(boundsSize.y, 1.0);
    float vFrac = clamp(position.y / h, 0.0, 1.0);
    float localThreshold = clamp(threshold * (1.0 - verticalBias * 0.65 + verticalBias * vFrac * 1.15), 0.0, 0.92);

    if (rnd < localThreshold) {
        half floorScale = half(clamp(minAlphaFloor, 0.0, 1.0));
        return half4(color.rgb * floorScale, color.a * floorScale);
    }
    return color;
}
