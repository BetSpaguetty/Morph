import SwiftUI

struct ContentView: View {
    private let screenCenter = Color(red: 232.0 / 255, green: 216.0 / 255, blue: 150.0 / 255) // #E8D896
    private let screenEdge = Color(red: 198.0 / 255, green: 172.0 / 255, blue: 88.0 / 255)     // #C6AC58

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
    }

    private func screenBackground(for size: CGSize) -> some View {
        let radius = min(size.width, size.height) * 0.11

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                EllipticalGradient(
                    colors: [screenCenter, screenEdge],
                    center: .center,
                    startRadiusFraction: 0.10,
                    endRadiusFraction: 0.45
                )
            )
            .frame(width: size.width * 0.90, height: size.height * 0.90)
    }
}

#Preview {
    ContentView()
}

