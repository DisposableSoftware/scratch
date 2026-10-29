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

/// Owns the navigation stacks' paths, one per tab: takes `.push` destinations from the Coordinator
/// and wraps a tab's root in a stack that shows them (ALB-8, PLST-6). A stack is told apart by the
/// kind of screen pushed onto it, the part of a push's key before the colon ("album:a1").
final class PushStackHost: ObservableObject, DestinationHandler, NavigationStackPort {
    @Published private(set) var paths: [String: [PushedScreen]] = [:]

    func handle(_ destination: NavigationDestination) -> Bool {
        guard case .push(let key, let view) = destination,
              let kind = key.split(separator: ":").first.map(String.init),
              var path = paths[kind]
        else { return false }

        if path.last?.key != key {
            path.append(PushedScreen(key: key, view: view))
            paths[kind] = path
        }

        return true
    }

    func stack(root: AnyView, pushing kind: String) -> AnyView {
        paths[kind] = []
        return AnyView(PushStack(host: self, kind: kind, root: root))
    }

    /// What a stack's back gestures leave.
    fileprivate func set(_ path: [PushedScreen], for kind: String) {
        paths[kind] = path
    }
}

private struct PushStack: View {
    @ObservedObject var host: PushStackHost
    let kind: String
    let root: AnyView

    var body: some View {
        NavigationStack(path: Binding(get: { host.paths[kind] ?? [] }, set: { host.set($0, for: kind) })) {
            root
                .navigationDestination(for: PushedScreen.self) { $0.view }
        }
    }
}
