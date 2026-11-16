import SwiftUI

struct ContentView: View {
    // MARK: - Paleta da Iluminação Interna (Visor Vintage Amarelado)
    /// Centro luminoso amarelo-creme claro (#E8D896)
    private let screenCenterColor = Color(red: 232.0 / 255.0, green: 216.0 / 255.0, blue: 150.0 / 255.0)
    /// Tom intermediário quente para suavizar a transição radial/retangular (#DBC778)
    private let screenMidColor = Color(red: 219.0 / 255.0, green: 199.0 / 255.0, blue: 120.0 / 255.0)
    /// Bordas internas em âmbar/mostarda profundo (#C6AC58)
    private let screenEdgeColor = Color(red: 198.0 / 255.0, green: 172.0 / 255.0, blue: 88.0 / 255.0)
    /// Sombra quente sutil no limite extremo da cavidade da moldura (#B59944)
    private let screenDeepRimColor = Color(red: 181.0 / 255.0, green: 153.0 / 255.0, blue: 68.0 / 255.0)

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let minDimension = min(containerWidth, containerHeight)

            // Dimensões da abertura interna visível da moldura ("borda_tv": ~82.6% x 81.5%)
            let apertureWidth = containerWidth * 0.826
            let apertureHeight = containerHeight * 0.815
            let apertureCornerRadius = minDimension * 0.096

            // Margem de sangria oculta atrás da carcaça para evitar frestas em distorções futuras
            let bleedMargin = minDimension * 0.045
            let bleedWidth = apertureWidth + (bleedMargin * 2.0)
            let bleedHeight = apertureHeight + (bleedMargin * 2.0)
            let bleedCornerRadius = apertureCornerRadius + (bleedMargin * 0.65)

            // Pequeno compensador de centro óptico da abertura da moldura
            let apertureOffsetX = containerWidth * 0.0025
            let apertureOffsetY = containerHeight * 0.0015

            ZStack {
                // Fundo escuro de segurança atrás de toda a estrutura
                Color.black
                    .ignoresSafeArea()

                // CAMADA 1 (Traseira Unificada): "Tela Interna" (Fundo Amarelado Iluminado + Logo Central)
                internalScreenView(
                    apertureWidth: apertureWidth,
                    apertureHeight: apertureHeight,
                    apertureCornerRadius: apertureCornerRadius,
                    bleedWidth: bleedWidth,
                    bleedHeight: bleedHeight,
                    bleedCornerRadius: bleedCornerRadius
                )
                .offset(x: apertureOffsetX, y: apertureOffsetY)

                // CAMADA 2 (Frontal Independente): Moldura Externa da TV
                Image("borda_tv")
                    .resizable()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .frame(width: containerWidth, height: containerHeight)
        }
        .ignoresSafeArea()
    }

    // MARK: - Tela Interna Unificada (Base Amarelada + Conteúdo Central)
    @ViewBuilder
    private func internalScreenView(
        apertureWidth: CGFloat,
        apertureHeight: CGFloat,
        apertureCornerRadius: CGFloat,
        bleedWidth: CGFloat,
        bleedHeight: CGFloat,
        bleedCornerRadius: CGFloat
    ) -> some View {
        let minAperture = min(apertureWidth, apertureHeight)

        ZStack {
            // 1. Base de sangria em âmbar/mostarda (#C6AC58) ultrapassando a abertura interna da moldura
            RoundedRectangle(cornerRadius: bleedCornerRadius, style: .continuous)
                .fill(screenEdgeColor)
                .frame(width: bleedWidth, height: bleedHeight)

            // 2. Iluminação elíptica base partindo do centro (#E8D896) até as extremidades (#C6AC58)
            RoundedRectangle(cornerRadius: bleedCornerRadius, style: .continuous)
                .fill(
                    EllipticalGradient(
                        stops: [
                            .init(color: screenCenterColor, location: 0.00),
                            .init(color: screenCenterColor.opacity(0.95), location: 0.28),
                            .init(color: screenMidColor, location: 0.62),
                            .init(color: screenEdgeColor, location: 0.90),
                            .init(color: screenDeepRimColor, location: 1.00)
                        ],
                        center: .center,
                        startRadiusFraction: 0.0,
                        endRadiusFraction: 0.56
                    )
                )
                .frame(width: bleedWidth, height: bleedHeight)

            // 3. Volume luminoso acompanhando o formato retangular com cantos arredondados da moldura
            RoundedRectangle(cornerRadius: apertureCornerRadius * 0.88, style: .continuous)
                .fill(
                    EllipticalGradient(
                        colors: [
                            screenCenterColor,
                            screenCenterColor.opacity(0.85),
                            screenMidColor.opacity(0.45),
                            Color.clear
                        ],
                        center: .center,
                        startRadiusFraction: 0.05,
                        endRadiusFraction: 0.55
                    )
                )
                .frame(width: apertureWidth * 0.88, height: apertureHeight * 0.86)
                .blur(radius: minAperture * 0.065)

            // 4. Vinheta interna contornando os cantos arredondados da abertura da TV (#C6AC58 -> #B59944)
            RoundedRectangle(cornerRadius: apertureCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            screenEdgeColor.opacity(0.85),
                            screenDeepRimColor.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: minAperture * 0.095
                )
                .frame(width: apertureWidth * 1.03, height: apertureHeight * 1.03)
                .blur(radius: minAperture * 0.048)

            // 5. Conteúdo central da tela (Logo "MORPH." integrada ao fundo amarelado)
            HomeView()
                .frame(width: apertureWidth, height: apertureHeight)
        }
        .frame(width: bleedWidth, height: bleedHeight)
        .clipShape(RoundedRectangle(cornerRadius: bleedCornerRadius, style: .continuous))
        // Grupo unificado pronto para receber texturas e shaders de curvatura nas próximas etapas
        .compositingGroup()
    }
}

#Preview {
    ContentView()
}


