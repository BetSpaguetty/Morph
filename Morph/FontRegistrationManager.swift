//
//  FontRegistrationManager.swift
//  teste_animacao
//
//  Registra dinamicamente todas as fontes (.ttf / .otf) incluídas no bundle (Times New Roman,
//  Serrif e Comic Sans MS) e resolve a combinação de Tom + Volume + Domínio.
//

import SwiftUI
import CoreText
import UIKit

struct ResolvedTypography {
    let font: Font
    let fontSize: CGFloat
    let familyName: String
    let weightLabel: String
    let extraStrokeWidth: CGFloat
    let whisperOpacityMultiplier: Double
}

final class FontRegistrationManager {

    static let shared = FontRegistrationManager()

    private var hasRegisteredFonts = false

    private init() {
        registerAllBundledFonts()
    }

    static func chicago(size: CGFloat) -> Font {
        shared.registerAllBundledFonts()
        return .custom("ChicagoFLF", size: size)
    }

    func registerAllBundledFonts() {
        guard !hasRegisteredFonts else { return }
        hasRegisteredFonts = true

        let extensions = ["ttf", "TTF", "otf", "OTF"]
        var urlsToRegister: [URL] = []

        for ext in extensions {
            if let rootURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                urlsToRegister.append(contentsOf: rootURLs)
            }
        }

        // Caso alguma subpasta tenha sido preservada dentro do bundle
        if let resourceURL = Bundle.main.resourceURL,
           let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if extensions.contains(fileURL.pathExtension) {
                    urlsToRegister.append(fileURL)
                }
            }
        }

        var seenPaths = Set<String>()
        for url in urlsToRegister {
            guard !seenPaths.contains(url.path) else { continue }
            seenPaths.insert(url.path)
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Calcula o tamanho da fonte a partir do parâmetro Domínio (-5 a +5).
    func fontSize(forDominio score: Int, baseSize: CGFloat = 34.0) -> CGFloat {
        let clamped = max(-5, min(5, score))
        switch clamped {
        case -5: return max(13.0, baseSize * 0.42)
        case -4: return max(16.0, baseSize * 0.52)
        case -3: return max(19.0, baseSize * 0.64)
        case -2: return max(23.0, baseSize * 0.76)
        case -1: return max(27.0, baseSize * 0.88)
        case 0:  return baseSize
        case 1:  return baseSize * 1.15
        case 2:  return baseSize * 1.32
        case 3:  return baseSize * 1.52
        case 4:  return baseSize * 1.75
        case 5:  return baseSize * 2.02
        default: return baseSize
        }
    }

    /// Resolve a tipografia combinando Tom (-5..+5), Volume (-5..+5) e Domínio (-5..+5).
    /// Regra definida para o Tom:
    /// -5 e -4 -> Times New Roman
    /// -3 e -2 -> Serif (Serrif bundled / New York fallback)
    /// -1, 0, +1, +2, +3 -> SF Padrão
    /// +4 e +5 -> Comic Sans
    func resolveTypography(
        tomScore: Int,
        volumeScore: Int,
        dominioScore: Int,
        baseSize: CGFloat = 34.0
    ) -> ResolvedTypography {
        registerAllBundledFonts()

        let size = fontSize(forDominio: dominioScore, baseSize: baseSize)
        let clampedTom = max(-5, min(5, tomScore))
        let clampedVol = max(-5, min(5, volumeScore))

        let swiftUIWeight = swiftUIFontWeight(forVolume: clampedVol)
        let weightName = weightDescription(forVolume: clampedVol)

        // Sussurro (-5..-1) e Grito (+2..+5) para reforço visual contínuo nos 11 degraus
        let whisperOpacity: Double = {
            switch clampedVol {
            case -5: return 0.42
            case -4: return 0.54
            case -3: return 0.66
            case -2: return 0.78
            case -1: return 0.90
            default: return 1.0
            }
        }()

        // 1. Tom -5 ou -4: Times New Roman
        if clampedTom <= -4 {
            let isBold = clampedVol >= 2
            let psName = isBold ? "TimesNewRomanPS-BoldMT" : "TimesNewRomanPSMT"
            let extraStroke = extraStrokeForTwoWeightFont(volume: clampedVol, fontSize: size)
            let chosenFont: Font = UIFont(name: psName, size: size) != nil
                ? .custom(psName, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .serif)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Times New Roman",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity
            )
        }

        // 2. Tom -3 ou -2: Serif (família Serrif incluída nos assets com 7 pesos reais!)
        if clampedTom == -3 || clampedTom == -2 {
            let serrifPS = serrifPostScriptName(forVolume: clampedVol)
            let extraStroke: CGFloat = clampedVol == 5 ? max(0.8, size * 0.024) : 0.0
            let chosenFont: Font = UIFont(name: serrifPS, size: size) != nil
                ? .custom(serrifPS, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .serif)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Serif",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity
            )
        }

        // 3. Tom +4 ou +5: Comic Sans
        if clampedTom >= 4 {
            let isBold = clampedVol >= 2
            let psName = isBold ? "ComicSansMS-Bold" : "ComicSansMS"
            let extraStroke = extraStrokeForTwoWeightFont(volume: clampedVol, fontSize: size)
            let chosenFont: Font = UIFont(name: psName, size: size) != nil
                ? .custom(psName, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .rounded)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Comic Sans",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity
            )
        }

        // 4. Outros valores (-1, 0, +1, +2, +3): SF Padrão
        let extraStroke: CGFloat = clampedVol == 5 ? max(0.6, size * 0.018) : 0.0
        return ResolvedTypography(
            font: .system(size: size, weight: swiftUIWeight, design: .monospaced),
            fontSize: size,
            familyName: "SF Padrão",
            weightLabel: weightName,
            extraStrokeWidth: extraStroke,
            whisperOpacityMultiplier: whisperOpacity
        )
    }

    private func serrifPostScriptName(forVolume volume: Int) -> String {
        switch volume {
        case -5, -4:
            return "Serrif-TRIAL-Thin"
        case -3, -2:
            return "Serrif-TRIAL-Light"
        case -1, 0:
            return "Serrif-TRIAL-Regular"
        case 1:
            return "Serrif-TRIAL-Medium"
        case 2:
            return "Serrif-TRIAL-SemiBold"
        case 3, 4:
            return "Serrif-TRIAL-Bold"
        case 5:
            return "Serrif-TRIAL-Heavy"
        default:
            return "Serrif-TRIAL-Regular"
        }
    }

    private func extraStrokeForTwoWeightFont(volume: Int, fontSize: CGFloat) -> CGFloat {
        switch volume {
        case 1: return max(0.35, fontSize * 0.012)
        case 2: return 0.0 // Transição para Bold nativo
        case 3: return max(0.55, fontSize * 0.018)
        case 4: return max(1.10, fontSize * 0.032)
        case 5: return max(1.80, fontSize * 0.050)
        default: return 0.0
        }
    }

    func swiftUIFontWeight(forVolume volume: Int) -> Font.Weight {
        switch volume {
        case -5: return .ultraLight
        case -4: return .thin
        case -3: return .light
        case -2: return .light
        case -1: return .regular
        case 0:  return .regular
        case 1:  return .medium
        case 2:  return .semibold
        case 3:  return .bold
        case 4:  return .heavy
        case 5:  return .black
        default: return .regular
        }
    }

    func weightDescription(forVolume volume: Int) -> String {
        switch volume {
        case -5: return "UltraLight (-5)"
        case -4: return "Thin (-4)"
        case -3: return "Light (-3)"
        case -2: return "Light+ (-2)"
        case -1: return "Soft Regular (-1)"
        case 0:  return "Regular (0)"
        case 1:  return "Medium (+1)"
        case 2:  return "Semibold (+2)"
        case 3:  return "Bold (+3)"
        case 4:  return "Heavy (+4)"
        case 5:  return "Black (+5)"
        default: return "Regular"
        }
    }
}
