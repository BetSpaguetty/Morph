#include <metal_stdlib>
using namespace metal;

/// Camada 1: Matriz de bolinhas esverdeadas para composição com .blendMode(.overlay) ou .softLight.
/// Cinza médio (0.5) é neutro (invisível); o deslocamento em torno de 0.5 mescla os pontos com a cor de baixo.
[[ stitchable ]] half4 crtDotsFilter(
    float2 position,
    half4 currentColor
) {
    constexpr float dotSpacing = 6.0;    // Distância entre centros (menor = mais bolinhas; maior = menos bolinhas)
    constexpr float dotRadius = 2.2;     // Raio da bolinha em pontos (não muda ao alterar dotSpacing)
    constexpr float dotIntensity = 0.78; // Força geral do padrão no .overlay / .softLight (0.0 a 1.0)

    float2 cellOffsetPts = (fract(position / dotSpacing) - 0.5) * dotSpacing;
    float distPts = length(cellOffsetPts);

    float dotMask = 1.0 - smoothstep(dotRadius * 0.45, dotRadius, distPts);

    // Textura fosca azulada fiel à camada de origem do Figma (azul sobre o fundo amarelo gera o subtom esverdeado)
    constexpr half3 meshColor = half3(0.24h, 0.31h, 0.36h);
    constexpr half3 dotColor = half3(0.48h, 0.67h, 0.78h);
    half3 pattern = mix(meshColor, dotColor, half(dotMask));
    half3 color = mix(half3(0.5h), pattern, half(dotIntensity));

    return half4(color, 1.0h);
}

/// Camada 2 (acima das bolinhas): Iluminação sobre o vidro da TV (manchas especulares laterais + vinheta nos cantos).
[[ stitchable ]] half4 crtGlassLightingFilter(
    float2 position,
    half4 currentColor,
    float2 size
) {
    float2 halfSize = max(size * 0.5, float2(1.0));
    float2 uv = (position - halfSize) / halfSize;
    float radialDist = length(uv);

    // Manchas curvas de luz especular no vidro (lados esquerdo e direito)
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

    // Profundidade: vinheta elíptica redonda nos 4 cantos + leve contraste no miolo central
    float cornerShadow = smoothstep(0.74, 1.24, radialDist) * 0.21;
    float centerDepth = exp(-pow(uv.x / 0.42, 2.0)) * (1.0 - smoothstep(0.0, 0.75, radialDist)) * 0.05;
    half shadowA = half(clamp(cornerShadow + centerDepth, 0.0, 0.30));
    half3 shadowRGB = half3(0.20h, 0.15h, 0.04h);

    // Brilho especular sobre a vinheta em alpha pré-multiplicado
    half3 premulRGB = glareRGB * glareA + shadowRGB * shadowA * (1.0h - glareA);
    half totalA = glareA + shadowA * (1.0h - glareA);

    return half4(premulRGB, totalA);
}
