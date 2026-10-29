/// A ViewModel-local route (ARCH-12): navigation within one screen, resolved against the
/// ViewModel that owns it.
protocol NavigationRoute {
    associatedtype Context

    func destination(context: Context) -> NavigationDestination
}

/// A ViewModel with routes. It names its Coordinator itself, as `useCases.coordinator`: a
/// `Has*` composition is an existential, so a `where UseCases: HasCoordinator` extension
/// could never apply to it.
protocol RoutingViewModel: ViewModel {
    associatedtype Route: NavigationRoute where Route.Context == Self

    var coordinator: Coordinator { get }
}

extension RoutingViewModel {
    func navigateTo(_ route: Route) async {
        await coordinator.navigateTo(route.destination(context: self))
    }
}
