@testable import Scratch

/// Records every destination it is asked to navigate to.
final class CoordinatorSpy: Coordinator {
    private(set) var destinations: [NavigationDestination] = []

    func navigateTo(_ destination: NavigationDestination) async {
        destinations.append(destination)
    }
}
