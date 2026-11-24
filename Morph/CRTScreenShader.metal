#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

inline half softLightChannel(half b, half s) {
    if (s <= 0.5h) {
        return b - (1.0h - 2.0h * s) * b * (1.0h - b);
    }
    half d = (b <= 0.25h)
        ? (((16.0h * b - 12.0h) * b + 4.0h) * b)
        : sqrt(b);
    return b + (2.0h * s - 1.0h) * (d - b);
}

/// Passe único Metal sobre a tela interna da TV:
/// 1) Distorção de barril normalizada à abertura visível da moldura (independente da proporção da tela)
/// 2) Superposição vetorial de múltiplos toques magnéticos (expulsão, vórtice, aberração RGB, luminância, scanlines e atenuação do teclado)
/// 3) Matriz procedural de bolinhas na coordenada distorcida com suavização óptica nas bordas + softLight
/// 4) Sombreamento convexo de domo (vinheta quente multiplicativa) + sombra de recuo da moldura + reflexo de vidro central
[[ stitchable ]] half4 crtScreenEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 openingOrigin,
    float2 openingSize,
    float curvature,
    float vignetteStrength,
    float bezelShadowStrength,
    float glassGlareStrength,
    device const float *touchData,
    int touchFloatCount,
    float4 touchParams1,
    float4 touchParams2,
    float4 touchParams3
) {
    float2 openingHalf = max(openingSize * 0.5, float2(1.0));
    float2 openingCenter = openingOrigin + openingHalf;

    // 1. Distorção de barril ancorada nos pontos médios das 4 bordas (edgeAnchor = 1.0)
    float2 uv = (position - openingCenter) / openingHalf;
    float k = max(curvature, 0.0);
    float r2 = dot(uv, uv);
    float radialDist = sqrt(r2);
    float factor = (1.0 + k * r2) / (1.0 + k);
    float2 srcPos = openingCenter + (uv * factor) * openingHalf;

    // 2. Superposição vetorial de múltiplos toques magnéticos (0 leituras de textura dentro do loop)
    float2 totalDisp = float2(0.0);
    float2 totalSplitVec = float2(0.0);
    float totalLum = 0.0;
    float maxScanInfluence = 0.0;
    bool hasTouchHit = false;

    int slotCount = touchFloatCount / 3;
    float radius = touchParams1.x;
    if (slotCount > 0 && radius > 0.5) {
        float force = touchParams1.y;
        float falloff = max(touchParams1.z, 0.1);
        float maxDispBudget = max(touchParams1.w, 0.0);

        float vortex = touchParams2.x;
        float rgbSplit = touchParams2.y;
        float centerLuminance = touchParams2.z;
        float scanlineVisibility = touchParams2.w;

        float keyboardStartY = touchParams3.x;
        float keyboardAttenuation = touchParams3.y;
        float maxSplitBudget = max(touchParams3.z, 0.0);

        float kbFactor = 1.0;
        if (keyboardAttenuation > 0.0 && keyboardStartY > 0.0 && srcPos.y > keyboardStartY) {
            float kbDepth = clamp((srcPos.y - keyboardStartY) / 100.0, 0.0, 1.0);
            kbFactor = 1.0 - (keyboardAttenuation * kbDepth);
        }

        if (kbFactor > 0.001) {
            float radiusSq = radius * radius;
            float invRadius = 1.0 / radius;
            bool linearFalloff = abs(falloff - 1.0) < 0.005;

            for (int i = 0; i < slotCount; ++i) {
                int base = i * 3;
                float touchActive = touchData[base + 2];
                if (touchActive <= 0.001) {
                    continue;
                }

                float2 toTouch = position - float2(touchData[base], touchData[base + 1]);
                float distSq = dot(toTouch, toTouch);
                if (distSq >= radiusSq) {
                    continue;
                }

                float invDist = (distSq > 0.000001) ? rsqrt(distSq) : 0.0;
                float dist = (distSq > 0.000001) ? (distSq * invDist) : 0.0;
                float normDist = dist * invRadius;
                float rawFactor = 1.0 - normDist;
                float curve = linearFalloff ? rawFactor : pow(rawFactor, falloff);
                float influence = curve * touchActive * kbFactor;

                if (influence <= 0.001) {
                    continue;
                }

                hasTouchHit = true;

                float2 radialDir = toTouch * invDist;
                float2 tangentDir = float2(-radialDir.y, radialDir.x);

                float radialMag = radius * 0.35 * force * influence;
                float twistMag = radius * 0.25 * vortex * influence;
                totalDisp += (radialDir * radialMag) + (tangentDir * twistMag);

                if (rgbSplit > 0.001) {
                    float2 splitDir = normalize(radialDir + tangentDir * 0.5 + float2(0.0001, 0.0001));
                    totalSplitVec += splitDir * (rgbSplit * influence);
                }

                if (centerLuminance != 0.0) {
                    totalLum += centerLuminance * influence * (1.0 - normDist * 0.4);
                }

                if (scanlineVisibility > 0.0) {
                    maxScanInfluence = max(maxScanInfluence, influence);
                }
            }

            if (hasTouchHit) {
                if (maxDispBudget > 0.0) {
                    float dispLenSq = dot(totalDisp, totalDisp);
                    if (dispLenSq > maxDispBudget * maxDispBudget) {
                        totalDisp *= maxDispBudget * rsqrt(dispLenSq);
                    }
                }
                if (maxSplitBudget > 0.0) {
                    float splitLenSq = dot(totalSplitVec, totalSplitVec);
                    if (splitLenSq > maxSplitBudget * maxSplitBudget) {
                        totalSplitVec *= maxSplitBudget * rsqrt(splitLenSq);
                    }
                }
            }
        }
    }

    // 3. Amostra fundo + UI (1 sample fora dos toques; no máximo 3 samples R/G/B dentro, com fallback screenEdge por canal)
    constexpr half3 screenEdge = half3(210.0h / 255.0h, 194.0h / 255.0h, 122.0h / 255.0h);
    float2 samplePos = hasTouchHit ? (srcPos - totalDisp) : srcPos;
    half3 baseRGB;

    if (hasTouchHit && dot(totalSplitVec, totalSplitVec) > 0.0001) {
        half4 sampleR = layer.sample(samplePos - totalSplitVec);
        half4 sampleG = layer.sample(samplePos);
        half4 sampleB = layer.sample(samplePos + totalSplitVec);
        baseRGB = half3(
            clamp(sampleR.r + screenEdge.r * (1.0h - sampleR.a), 0.0h, 1.0h),
            clamp(sampleG.g + screenEdge.g * (1.0h - sampleG.a), 0.0h, 1.0h),
            clamp(sampleB.b + screenEdge.b * (1.0h - sampleB.a), 0.0h, 1.0h)
        );
    } else {
        half4 sampled = layer.sample(samplePos);
        baseRGB = clamp(sampled.rgb + screenEdge * (1.0h - sampled.a), half3(0.0h), half3(1.0h));
    }

    // 4. Bolinhas procedurais na coordenada distorcida + suavização sutil nas extremidades do vidro (como no Figma)
    constexpr float dotSpacing = 6.0;
    constexpr float dotRadius = 2.2;
    constexpr float baseDotIntensity = 0.78;

    float2 cellOffsetPts = (fract(samplePos / dotSpacing) - 0.5) * dotSpacing;
    float distPts = length(cellOffsetPts);
    float rimSoftness = smoothstep(0.82, 1.28, radialDist);
    float aa = max(0.0, (factor - 1.0) * 0.45) + rimSoftness * 0.45;
    float dotMask = 1.0 - smoothstep(dotRadius * 0.45, dotRadius + aa, distPts);
    float dotIntensity = baseDotIntensity * (1.0 - rimSoftness * 0.36);

    constexpr half3 meshColor = half3(0.24h, 0.31h, 0.36h);
    constexpr half3 dotColor = half3(0.48h, 0.67h, 0.78h);
    half3 dotPattern = mix(meshColor, dotColor, half(dotMask));
    half3 dotSource = mix(half3(0.5h), dotPattern, half(dotIntensity));

    half3 litRGB = half3(
        softLightChannel(baseRGB.r, dotSource.r),
        softLightChannel(baseRGB.g, dotSource.g),
        softLightChannel(baseRGB.b, dotSource.b)
    );

    // 4b. Mancha de luminância central e scanlines reveladas dentro da área tocada
    if (hasTouchHit) {
        if (totalLum != 0.0) {
            half lum = half(clamp(totalLum, -1.0, 1.0));
            litRGB = clamp(litRGB + half3(lum), half3(0.0h), half3(1.0h));
        }

        float scanlineVisibility = touchParams2.w;
        if (scanlineVisibility > 0.0 && maxScanInfluence > 0.001) {
            float scanlinePattern = sin(position.y * 1.8) * 0.5 + 0.5;
            float scanDarken = clamp(scanlineVisibility * maxScanInfluence * 0.55 * (1.0 - scanlinePattern), 0.0, 0.95);
            litRGB *= half(1.0 - scanDarken);
        }
    }

    // 5a. Vinheta convexa multiplicativa em tom quente (superfície do tubo virando para longe do observador)
    float domeFactor = smoothstep(0.42, 1.32, radialDist);
    float v = clamp(domeFactor * max(vignetteStrength, 0.0), 0.0, 0.85);
    half3 domeShade = clamp(
        half3(1.0h - half(v * 0.90), 1.0h - half(v * 0.95), 1.0h - half(v * 1.12)),
        half3(0.12h),
        half3(1.0h)
    );
    litRGB *= domeShade;

    // 4b. Sombra de recuo/contato da moldura (SDF do recorte arredondado + luz ambiente vindo de cima)
    float2 q = abs(uv) - float2(0.86, 0.86);
    float bezelDist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.14;
    float edgeProximity = smoothstep(-0.22, 0.02, bezelDist);
    float topBias = smoothstep(-0.68, -1.02, uv.y) * 0.28;
    float bezelOcc = clamp((pow(edgeProximity, 1.55) + topBias * edgeProximity) * max(bezelShadowStrength, 0.0), 0.0, 0.90);
    half3 bezelShade = mix(half3(1.0h), half3(0.18h, 0.15h, 0.08h), half(bezelOcc));
    litRGB *= bezelShade;

    // 4c. Reflexo especular de domo central/superior (reforça o volume estufado sem clarear as laterais)
    float glareRimFade = 1.0 - smoothstep(0.55, 1.02, radialDist);
    float2 domeSpecUV = (uv - float2(-0.12, -0.20)) / float2(0.74, 0.56);
    float domeSpec = exp(-dot(domeSpecUV, domeSpecUV) * 1.45);
    float2 upperArcUV = (uv - float2(-0.20, -0.54)) / float2(0.72, 0.24);
    float upperArc = exp(-dot(upperArcUV, upperArcUV) * 2.2) * 0.45;
    half glareA = half(clamp((domeSpec * 0.48 + upperArc) * glareRimFade * max(glassGlareStrength, 0.0), 0.0, 0.32));
    half3 glareRGB = half3(1.0h, 0.99h, 0.94h);

    half3 finalRGB = mix(litRGB, glareRGB, glareA);
    return half4(clamp(finalRGB, half3(0.0h), half3(1.0h)), 1.0h);
}
