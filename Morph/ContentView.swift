import SwiftUI
import Observation

enum MorphRoute: Hashable {
    case editor
}

/// Roteador SwiftUI puro (sem UINavigationController) para que todas as telas futuras
/// fiquem dentro do passe Metal da TV sem quebrar a distorção de barril.
@MainActor
@Observable
final class MorphRouter {
    private(set) var path: [MorphRoute] = []

    var current: MorphRoute? { path.last }

    func push(_ route: MorphRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}

struct ContentView: View {
    private let screenCenter = Color(red: 238.0 / 255, green: 230.0 / 255, blue: 184.0 / 255) // #EEE6B8
    private let screenEdge = Color(red: 210.0 / 255, green: 194.0 / 255, blue: 122.0 / 255)   // #D2C27A

    @State private var router = MorphRouter()
    @State private var crtConfig = CRTBarrelConfig()
    @State private var keyboardConfig = MorphKeyboardVisualConfig()
    @State private var textInputBridge = CRTTextInputBridge()
    @State private var touchEngine = CRTMagneticTouchEngine()

    var body: some View {
        GeometryReader { geo in
            let transform = CRTBarrelTransform(
                containerSize: geo.size,
                curvature: CGFloat(crtConfig.curvature)
            )

            ZStack {
                Color.black

                // 1. Tela interna 100% SwiftUI sob passe único Metal (barril + toque magnético + bolinhas + iluminação)
                ZStack {
                    screenBackground

                    currentScreen
                        .frame(
                            width: transform.openingRect.width,
                            height: transform.openingRect.height
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .coordinateSpace(name: CRTCoordinateSpace.name)
                .environment(\.crtBarrelTransform, transform)
                .environment(router)
                .environment(crtConfig)
                .environment(keyboardConfig)
                .environment(textInputBridge)
                .compositingGroup()
                .modifier(
                    CRTScreenEffectModifier(
                        transform: transform,
                        barrelConfig: crtConfig,
                        touchEngine: touchEngine,
                        textInputBridge: textInputBridge
                    )
                )

                // 2. Input UIKit invisível fora do shader Metal (somente durante edição de texto)
                if let session = textInputBridge.session {
                    CRTTextInputOverlay(
                        session: session,
                        editorFrame: textInputBridge.editorFrameInCRT,
                        excludedFrames: textInputBridge.excludedFramesInCRT,
                        barrelTransform: transform
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                // 2b. Observador passivo UIKit de multitoque (cobre toda a tela da TV sem bloquear nenhum gesto)
                CRTPassiveTouchObserver(engine: touchEngine, transform: transform)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)

                // 3. Moldura física da TV por cima, ocupando 100% da tela
                Image("borda_tv")
                    .resizable()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var currentScreen: some View {
        ZStack {
            switch router.current {
            case nil:
                HomeView()
                    .transition(.opacity)
            case .editor:
                TextView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.current)
    }

    /// Fundo cobre 100% atrás da moldura RGBA para evitar qualquer fresta preta em curvaturas altas.
    private var screenBackground: some View {
        Rectangle()
            .fill(
                EllipticalGradient(
                    colors: [screenCenter, screenEdge],
                    center: .center,
                    startRadiusFraction: 0.09,
                    endRadiusFraction: 0.522
                )
            )
    }
}

#Preview {
    ContentView()
}
