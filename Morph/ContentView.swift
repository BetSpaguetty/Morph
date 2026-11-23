import SwiftUI

struct ContentView: View {
    private let screenCenter = Color(red: 238.0 / 255, green: 230.0 / 255, blue: 184.0 / 255) // #EEE6B8
    private let screenEdge = Color(red: 210.0 / 255, green: 194.0 / 255, blue: 122.0 / 255)   // #D2C27A

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // Tela interna (fundo com sangria + UI navegável + filtro CRT Metal sobre toda a tela)
                ZStack {
                    screenBackground(for: geo.size)

                    NavigationStack {
                        HomeView()
                    }
                    .frame(width: geo.size.width * 0.826, height: geo.size.height * 0.815)

                    CRTScreenFilterView(containerSize: geo.size)
                }
                .compositingGroup()

                Image("borda_tv")
                    .resizable()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    private func screenBackground(for size: CGSize) -> some View {
        let radius = min(size.width, size.height) * 0.11

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                EllipticalGradient(
                    colors: [screenCenter, screenEdge],
                    center: .center,
                    startRadiusFraction: 0.10,
                    endRadiusFraction: 0.58
                )
            )
            .frame(width: size.width * 0.90, height: size.height * 0.90)
    }
}

#Preview {
    ContentView()
}

