import SwiftUI

/// The navigation engine. Feature code asks it to go somewhere; only the host (`App/`) knows how
/// a destination is actually shown (ARCH-13).
protocol Coordinator: AnyObject {
    func navigateTo(_ destination: NavigationDestination) async
}

/// Everywhere the Coordinator can take the user. Destinations carry views, which is why the
/// navigation mechanism lives in `UI/` and `Routing/` holds only the pure Routers.
enum NavigationDestination {
    /// Replace the whole screen, as when moving between setup and the library.
    case root(AnyView)
    case sheet(AnyView)
    case dismissSheet
    case alert(AlertContent)
}

struct AlertContent: Equatable {
    var title: String
    var message: String
}
