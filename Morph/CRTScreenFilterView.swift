import SwiftUI

/// Camada de filtro CRT aplicada sobre toda a interface da TV:
/// 1) Bolinhas mescladas ao fundo (.overlay / .softLight)
/// 2) Iluminação sobre o vidro (brilho especular lateral + vinheta nos cantos) acima das bolinhas.
struct CRTScreenFilterView: View {
    let containerSize: CGSize

    var body: some View {
        let filterSize = CGSize(
            width: containerSize.width * 0.90,
            height: containerSize.height * 0.90
        )
        let radius = min(containerSize.width, containerSize.height) * 0.11
        let screenShape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack {
            // 1. Bolinhas mescladas com a tela e elementos abaixo
            screenShape
                .fill(.white)
                .colorEffect(ShaderLibrary.crtDotsFilter())
                .blendMode(.softLight)

            // 2. Iluminação do vidro aplicada acima das bolinhas
            screenShape
                .fill(.white)
                .colorEffect(
                    ShaderLibrary.crtGlassLightingFilter(
                        .float2(filterSize.width, filterSize.height)
                    )
                )
        }
        .frame(width: filterSize.width, height: filterSize.height)
        .allowsHitTesting(false)
    }
}
