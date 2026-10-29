/// The composition root: the only place concrete UseCases, Gateways, Routers and RoutingUseCases
/// are built (ARCH-14).
struct AppContainer: AllUseCases {
    let coordinator: Coordinator
}

extension AppContainer {
    /// Takes only what the app can't create itself.
    static func build(coordinator: Coordinator) -> AppContainer {
        AppContainer(coordinator: coordinator)
    }
}
