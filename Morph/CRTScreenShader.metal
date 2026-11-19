#include <metal_stdlib>
using namespace metal;

/// Filtro CRT estático em coordenadas de pontos (densidade física constante em qualquer tamanho de tela).
/// Combina micropontos claros, brilho especular lateral do vidro (esquerdo/direito) e vinheta elíptica nos cantos.
[[ stitchable ]] half4 crtScreenFilter(
    float2 position,
    half4 currentColor,
    float2 size
) {
    // 1. Matriz de pontos claros levemente maiores (5.6 pt por célula)
    constexpr float cellSize = 5.6;
    float2 cellUV = fract(position / cellSize) - 0.5;
    float distToDotCenter = length(cellUV);

    float dotMask = 1.0 - smoothstep(0.08, 0.27, distToDotCenter);
    half dotA = half(dotMask * 0.24);
    half3 dotRGB = half3(1.0h, 0.98h, 0.86h);

    // Coordenadas normalizadas [-1, 1] a partir do centro da tela
    float2 halfSize = max(size * 0.5, float2(1.0));
    float2 uv = (position - halfSize) / halfSize;
    float radialDist = length(uv);

    // 2. Manchas curvas de luz especular no vidro (lados esquerdo e direito)
    float leftAxisX = -0.64 + 0.12 * (uv.y * uv.y) + 0.04 * uv.y;
    float leftDx = (uv.x - leftAxisX) / 0.21;
    float leftLobe = exp(-leftDx * leftDx);
    float leftVert = smoothstep(-0.88, -0.35, uv.y) * (1.0 - smoothstep(0.15, 0.82, uv.y));

    float rightAxisX = 0.56 - 0.12 * (uv.y * uv.y) + 0.10 * uv.y;
    float rightDx = (uv.x - rightAxisX) / 0.24;
    float rightLobe = exp(-rightDx * rightDx);
    float rightVert = smoothstep(-0.90, -0.38, uv.y) * (1.0 - smoothstep(0.20, 0.85, uv.y));

    float glareRimFade = 1.0 - smoothstep(0.76, 0.98, radialDist);
    float glareStrength = (leftLobe * leftVert * 0.22 + rightLobe * rightVert * 0.24) * glareRimFade;
    half glareA = half(clamp(glareStrength, 0.0, 0.28));
    half3 glareRGB = half3(1.0h, 0.99h, 0.94h);

    // 3. Profundidade: vinheta elíptica redonda nos 4 cantos + leve contraste no miolo central
    float cornerShadow = smoothstep(0.74, 1.24, radialDist) * 0.21;
    float centerDepth = exp(-pow(uv.x / 0.42, 2.0)) * (1.0 - smoothstep(0.0, 0.75, radialDist)) * 0.05;
    half shadowA = half(clamp(cornerShadow + centerDepth, 0.0, 0.30));
    half3 shadowRGB = half3(0.20h, 0.15h, 0.04h);

    // 4. Composição associativa em alpha pré-multiplicado: Pontos sobre Brilho sobre Sombra
    half3 lightPremul = dotRGB * dotA + glareRGB * glareA * (1.0h - dotA);
    half lightA = dotA + glareA * (1.0h - dotA);

    half3 premulRGB = lightPremul + shadowRGB * shadowA * (1.0h - lightA);
    half totalA = lightA + shadowA * (1.0h - lightA);

    return half4(premulRGB, totalA);
}
