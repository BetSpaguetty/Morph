import SwiftUI

// MARK: - Modelo das Camadas, Teclas e Acentos (Fiel aos Protótipos Figma)

enum MorphKeyboardLayer: Equatable {
    case letters
    case numbers
    case symbols
}

enum MorphShiftState: Equatable {
    case off
    case once
    case capsLock

    var isUppercase: Bool { self != .off }
}

enum MorphKeyAction: Hashable {
    case character(String)
    case shift
    case backspace
    case switchLayer(MorphKeyboardLayer)
    case space
    case returnKey
    case dismiss
}

struct MorphKeySpec: Identifiable, Hashable {
    let id: String
    let action: MorphKeyAction
    let widthWeight: CGFloat
    let accents: [String]
    let defaultAccentIndex: Int

    var hasAccents: Bool { !accents.isEmpty }
}

enum MorphKeyboardLayout {
    private static let accentMap: [String: (options: [String], defaultIndex: Int)] = [
        // Letras à esquerda expandem para a direita; letras à direita expandem para a esquerda (como no iOS)
        "a": (["a", "á", "â", "ã", "à", "ä", "ª"], 0),
        "e": (["e", "é", "ê", "è", "ë"], 0),
        "i": (["ï", "ì", "î", "í", "i"], 4),
        "o": (["º", "ö", "ò", "õ", "ô", "ó", "o"], 6),
        "u": (["ü", "ù", "û", "ú", "u"], 4),
        "c": (["c", "ç"], 0),
        "n": (["ñ", "n"], 1)
    ]

    static func rows(for layer: MorphKeyboardLayer) -> [[MorphKeySpec]] {
        switch layer {
        case .letters:
            return [
                charRow(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], prefix: "L1"),
                charRow(["a", "s", "d", "f", "g", "h", "j", "k", "l"], prefix: "L2"),
                [specialKey(id: "L3_shift", action: .shift, weight: 1.12)]
                    + charRow(["z", "x", "c", "v", "b", "n", "m"], prefix: "L3")
                    + [specialKey(id: "L3_bs", action: .backspace, weight: 1.28)],
                [
                    specialKey(id: "L4_123", action: .switchLayer(.numbers), weight: 1.45),
                    specialKey(id: "L4_space", action: .space, weight: 4.95),
                    specialKey(id: "L4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "L4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]

        case .numbers:
            return [
                charRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], prefix: "N1"),
                charRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""], prefix: "N2"),
                [specialKey(id: "N3_sym", action: .switchLayer(.symbols), weight: 1.48)]
                    + charRow([".", ",", "?", "!", "'"], prefix: "N3")
                    + [specialKey(id: "N3_bs", action: .backspace, weight: 1.48)],
                [
                    specialKey(id: "N4_abc", action: .switchLayer(.letters), weight: 1.45),
                    specialKey(id: "N4_space", action: .space, weight: 4.95),
                    specialKey(id: "N4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "N4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]

        case .symbols:
            return [
                charRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], prefix: "S1"),
                charRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"], prefix: "S2"),
                [specialKey(id: "S3_123", action: .switchLayer(.numbers), weight: 1.48)]
                    + charRow([".", ",", "?", "!", "'"], prefix: "S3")
                    + [specialKey(id: "S3_bs", action: .backspace, weight: 1.48)],
                [
                    specialKey(id: "S4_abc", action: .switchLayer(.letters), weight: 1.45),
                    specialKey(id: "S4_space", action: .space, weight: 4.95),
                    specialKey(id: "S4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "S4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]
        }
    }

    static func resolvedAccentOptions(for key: MorphKeySpec, uppercase: Bool) -> [String] {
        guard key.hasAccents else { return [] }
        return key.accents.map { option in
            if option == "ª" || option == "º" { return option }
            return uppercase ? option.uppercased() : option
        }
    }

    private static func charRow(_ chars: [String], prefix: String) -> [MorphKeySpec] {
        chars.enumerated().map { idx, ch in
            let entry = accentMap[ch]
            return MorphKeySpec(
                id: "\(prefix)_\(idx)_\(ch)",
                action: .character(ch),
                widthWeight: 1.0,
                accents: entry?.options ?? [],
                defaultAccentIndex: entry?.defaultIndex ?? 0
            )
        }
    }

    private static func specialKey(id: String, action: MorphKeyAction, weight: CGFloat) -> MorphKeySpec {
        MorphKeySpec(id: id, action: action, widthWeight: weight, accents: [], defaultAccentIndex: 0)
    }
}
