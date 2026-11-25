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
