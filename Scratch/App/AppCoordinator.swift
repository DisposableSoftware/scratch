import Combine
import SwiftUI

/// Performs navigation for the destinations it knows. The host registers these with the
/// Coordinator.
protocol DestinationHandler: AnyObject {
    /// Shows the destination and returns true, or returns false if it isn't this handler's kind.
    func handle(_ destination: NavigationDestination) -> Bool
}

/// The app's Coordinator: hands each destination to the first registered handler that takes it.
final class AppCoordinator: Coordinator {
    private var handlers: [DestinationHandler] = []

    func register(_ handler: DestinationHandler) {
        handlers.append(handler)
    }

    func navigateTo(_ destination: NavigationDestination) async {
        for handler in handlers where handler.handle(destination) {
            return
        }
        assertionFailure("No handler registered for \(destination)")
    }
}

/// Owns what the root window shows: the current screen, a sheet over it, and an alert.
final class RootPresenter: ObservableObject, DestinationHandler {
    @Published var screen: AnyView?
    @Published var sheet: AnyView?
    @Published var alert: AlertContent?

    func handle(_ destination: NavigationDestination) -> Bool {
        switch destination {
        case .push:
            // The navigation stack takes these (PushStackHost).
            return false
        case .root(let view):
            sheet = nil
            screen = view
        case .sheet(let view):
            sheet = view
        case .dismissSheet:
            sheet = nil
        case .alert(let content):
            alert = content
        }
        return true
    }
}
