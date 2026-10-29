/// The composition root: the only place concrete UseCases, Gateways, Routers and RoutingUseCases
/// are built (ARCH-14).
struct AppContainer: AllUseCases {
    let coordinator: Coordinator
    let appRouting: AppRoutingUseCase
}

extension AppContainer {
    /// Takes only what the app can't create itself.
    static func build(coordinator: Coordinator) -> AppContainer {
        // 1. Shared state
        let sessionState = SessionState()

        // 2. Routers
        let viewFactory = AppViewFactory()
        let appRouting = DefaultAppRoutingUseCase(
            router: AppRouter(sessionState: sessionState),
            coordinator: coordinator,
            viewFactory: viewFactory
        )

        // 3. Assemble, then let the view factory build ViewModels from the result.
        let container = AppContainer(coordinator: coordinator, appRouting: appRouting)
        viewFactory.useCases = container
        return container
    }
}
