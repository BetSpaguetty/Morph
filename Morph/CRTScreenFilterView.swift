import SwiftUI

/// Camada de filtro CRT (micropontos claros + vinheta elíptica suave) aplicada sobre toda a interface da TV.
/// Permanece transparente a toques para que todos os controles abaixo continuem clicáveis.
struct CRTScreenFilterView: View {
    let containerSize: CGSize

    var body: some View {
        let filterSize = CGSize(
            width: containerSize.width * 0.90,
            height: containerSize.height * 0.90
        )
        let radius = min(containerSize.width, containerSize.height) * 0.11

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.white)
            .frame(width: filterSize.width, height: filterSize.height)
            .colorEffect(
                ShaderLibrary.crtScreenFilter(
                    .float2(filterSize.width, filterSize.height)
                )
            )
            .allowsHitTesting(false)
    }
}
