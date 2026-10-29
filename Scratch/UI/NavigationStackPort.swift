import SwiftUI

/// A Port (ARCH-15): the navigation stack a tab's screens are pushed onto belongs to the host,
/// since only the host keeps its path. Screens are pushed by handing the Coordinator a `.push`
/// destination, never by a Link in a View (ARCH-12, ARCH-13).
protocol NavigationStackPort {
    /// The root screen inside a stack that `.push` destinations of this kind are added to: the kind
    /// is the part of a push's key before the colon. Asking again for a kind starts its stack over,
    /// with nothing pushed.
    func stack(root: AnyView, pushing kind: String) -> AnyView
}
