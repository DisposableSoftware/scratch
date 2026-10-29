import Combine
import SwiftUI

/// A screen on the navigation stack, told apart by identity, since views can't be compared.
struct PushedScreen: Hashable, Identifiable {
    let id = UUID()

    /// What the screen is, so the same one isn't pushed on top of itself.
    let key: String
    let view: AnyView

    static func == (lhs: PushedScreen, rhs: PushedScreen) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Owns the navigation stack's path: takes `.push` destinations from the Coordinator and wraps a
/// tab's root in a stack that shows them (ALB-8).
final class PushStackHost: ObservableObject, DestinationHandler, NavigationStackPort {
    @Published var path: [PushedScreen] = []

    func handle(_ destination: NavigationDestination) -> Bool {
        guard case .push(let key, let view) = destination else { return false }

        if path.last?.key != key {
            path.append(PushedScreen(key: key, view: view))
        }

        return true
    }

    func stack(root: AnyView) -> AnyView {
        path = []
        return AnyView(PushStack(host: self, root: root))
    }
}

private struct PushStack: View {
    @ObservedObject var host: PushStackHost
    let root: AnyView

    var body: some View {
        NavigationStack(path: $host.path) {
            root
                .navigationDestination(for: PushedScreen.self) { $0.view }
        }
    }
}
