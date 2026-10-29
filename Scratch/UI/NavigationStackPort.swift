import SwiftUI

/// A Port (ARCH-15): the navigation stack a tab's screens are pushed onto belongs to the host,
/// since only the host keeps its path. Screens are pushed by handing the Coordinator a `.push`
/// destination, never by a Link in a View (ARCH-12, ARCH-13).
protocol NavigationStackPort {
    /// The root screen inside a stack that `.push` destinations are added to. Asking again starts
    /// a stack of its own, with nothing pushed.
    func stack(root: AnyView) -> AnyView
}
