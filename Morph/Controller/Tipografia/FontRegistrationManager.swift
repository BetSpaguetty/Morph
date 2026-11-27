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

    /// Termos explícitos que indicam gato/felino ou vocalizações características.
    static func isFelineTerm(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let tokens = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let felineTerms: Set<String> = [
            "gato", "gata", "gatos", "gatas", "gatinho", "gatinha", "gatinhos", "gatinhas", "gatao", "gataoes",
            "felino", "felina", "felinos", "felinas",
            "cat", "cats", "kitten", "kittens", "kitty", "kitties", "feline", "felines", "tomcat", "tabby",
            "miau", "miaulado", "miado", "ronronar", "ronronando", "ronronou", "ronronava", "purr", "purring"
        ]
        return tokens.contains { felineTerms.contains($0) }
    }

    /// Resolve a tipografia combinando Tom (-5..+5), Domínio (-5..+5: tamanho e espessura),
    /// Calor (SnowtopCaps em <= -2) e contexto felino (CatsFont), além de opacidade suave para Volume negativo.
    /// Regra de família:
    /// - Contexto felino -> CatsFont (temático)
    /// - Disputa entre SnowtopCaps (Calor <= -2) e Tom estilizado (-5..-2 ou +4..+5): vence maior |nota|; empate determinístico por `tieBreakSeed`.
    /// - Tom: -5/-4 Times New Roman, -3/-2 Serif, -1..+3 SF Mono, +4/+5 Comic Sans.
    func resolveTypography(
        tomScore: Int,
        volumeScore: Int,
        dominioScore: Int,
        calorScore: Int = 0,
        felineContext: Bool = false,
        baseSize: CGFloat = 34.0,
        tieBreakSeed: Int = 0
    ) -> ResolvedTypography {
        registerAllBundledFonts()

        let clampedDominio = max(-5, min(5, dominioScore))
        let size = fontSize(forDominio: clampedDominio, baseSize: baseSize)
        let clampedTom = max(-5, min(5, tomScore))
        let clampedVol = max(-5, min(5, volumeScore))
        let clampedCalor = max(-5, min(5, calorScore))

        // Espessura migrada de Volume para Domínio.
        let swiftUIWeight = swiftUIFontWeight(forDominio: clampedDominio)
        let weightName = weightDescription(forDominio: clampedDominio)

        // Sussurro (-5..-1) atenua levemente a opacidade sem competir com a espessura de Domínio.
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

        // Fontes ilustradas (CatsFont e SnowtopCaps) não recebem extraStroke artificial para preservar o desenho.
        if felineContext {
            let catsFont = UIFont(name: "CatsFont-Regular", size: size) != nil
                ? Font.custom("CatsFont-Regular", fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .rounded)
            return ResolvedTypography(
                font: catsFont,
                fontSize: size,
                familyName: "Cats Font",
                weightLabel: weightName,
                extraStrokeWidth: 0.0,
                whisperOpacityMultiplier: whisperOpacity,
                isDecorativeSingleWeight: true
            )
        }

        let tomHasStyledFamily = (clampedTom <= -2 || clampedTom >= 4)
        let snowtopEligible = clampedCalor <= -2
        let useSnowtopCaps: Bool = {
            guard snowtopEligible else { return false }
            guard tomHasStyledFamily else { return true }
            let calorMag = abs(clampedCalor)
            let tomMag = abs(clampedTom)
            if calorMag != tomMag { return calorMag > tomMag }
            // Empate exato resolvido deterministicamente pelo seed da palavra.
            return (tieBreakSeed & 1) == 0
        }()

        if useSnowtopCaps {
            let snowtopCaps = UIFont(name: "SnowtopCaps", size: size) != nil
                ? Font.custom("SnowtopCaps", fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .rounded)
            return ResolvedTypography(
                font: snowtopCaps,
                fontSize: size,
                familyName: "Snowtop Caps",
                weightLabel: weightName,
                extraStrokeWidth: 0.0,
                whisperOpacityMultiplier: whisperOpacity,
                isDecorativeSingleWeight: true
            )
        }

        // 1. Tom -5 ou -4: Times New Roman
        if clampedTom <= -4 {
            let isBold = clampedDominio >= 2
            let psName = isBold ? "TimesNewRomanPS-BoldMT" : "TimesNewRomanPSMT"
            let extraStroke = extraStrokeForTwoWeightFont(dominio: clampedDominio, fontSize: size)
            let chosenFont: Font = UIFont(name: psName, size: size) != nil
                ? .custom(psName, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .serif)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Times New Roman",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity,
                isDecorativeSingleWeight: false
            )
        }

        // 2. Tom -3 ou -2: Serif (família Serrif incluída nos assets com 7 pesos reais!)
        if clampedTom == -3 || clampedTom == -2 {
            let serrifPS = serrifPostScriptName(forDominio: clampedDominio)
            let extraStroke: CGFloat = clampedDominio == 5 ? max(0.8, size * 0.024) : 0.0
            let chosenFont: Font = UIFont(name: serrifPS, size: size) != nil
                ? .custom(serrifPS, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .serif)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Serif",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity,
                isDecorativeSingleWeight: false
            )
        }

        // 3. Tom +4 ou +5: Comic Sans
        if clampedTom >= 4 {
            let isBold = clampedDominio >= 2
            let psName = isBold ? "ComicSansMS-Bold" : "ComicSansMS"
            let extraStroke = extraStrokeForTwoWeightFont(dominio: clampedDominio, fontSize: size)
            let chosenFont: Font = UIFont(name: psName, size: size) != nil
                ? .custom(psName, fixedSize: size)
                : .system(size: size, weight: swiftUIWeight, design: .rounded)

            return ResolvedTypography(
                font: chosenFont,
                fontSize: size,
                familyName: "Comic Sans",
                weightLabel: weightName,
                extraStrokeWidth: extraStroke,
                whisperOpacityMultiplier: whisperOpacity,
                isDecorativeSingleWeight: false
            )
        }

        // 4. Outros valores (-1, 0, +1, +2, +3): SF Padrão (monospaced)
        let extraStroke: CGFloat = clampedDominio == 5 ? max(0.6, size * 0.018) : 0.0
        return ResolvedTypography(
            font: .system(size: size, weight: swiftUIWeight, design: .monospaced),
            fontSize: size,
            familyName: "SF Padrão",
            weightLabel: weightName,
            extraStrokeWidth: extraStroke,
            whisperOpacityMultiplier: whisperOpacity,
            isDecorativeSingleWeight: false
        )
    }

    private func serrifPostScriptName(forDominio dominio: Int) -> String {
        switch dominio {
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

    private func extraStrokeForTwoWeightFont(dominio: Int, fontSize: CGFloat) -> CGFloat {
        switch dominio {
        case 1: return max(0.35, fontSize * 0.012)
        case 2: return 0.0 // Transição para Bold nativo
        case 3: return max(0.55, fontSize * 0.018)
        case 4: return max(1.10, fontSize * 0.032)
        case 5: return max(1.80, fontSize * 0.050)
        default: return 0.0
        }
    }

    func swiftUIFontWeight(forDominio dominio: Int) -> Font.Weight {
        switch dominio {
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

    func weightDescription(forDominio dominio: Int) -> String {
        switch dominio {
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
