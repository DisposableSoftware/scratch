import Foundation

/// The composition root: the only place concrete UseCases, Gateways, Routers and RoutingUseCases
/// are built (ARCH-14).
struct AppContainer: AllUseCases {
    let coordinator: Coordinator
    let appRouting: AppRoutingUseCase
    let connectUseCase: ConnectUseCase
    let sessionUseCase: SessionUseCase
}

extension AppContainer {
    /// Takes only what the app can't create itself.
    static func build(
        coordinator: Coordinator,
        networkSession: NetworkSession,
        environment: AppEnvironment
    ) -> AppContainer {
        // 1. Shared state
        let sessionState = SessionState()

        // 2. Gateways
        let serverGateway = RemoteServerGateway(networkSession: networkSession)
        let credentialGateway = KeychainCredentialGateway(environment: environment)

        // 3. UseCases
        let connectUseCase = DefaultConnectUseCase(
            serverGateway: serverGateway,
            credentialGateway: credentialGateway,
            sessionState: sessionState
        )
        let sessionUseCase = DefaultSessionUseCase(credentialGateway: credentialGateway, sessionState: sessionState)

        // 4. Routers
        let viewFactory = AppViewFactory()
        let appRouting = DefaultAppRoutingUseCase(
            router: AppRouter(sessionState: sessionState),
            coordinator: coordinator,
            viewFactory: viewFactory
        )

        // 5. Assemble, then let the view factory build ViewModels from the result.
        let container = AppContainer(
            coordinator: coordinator,
            appRouting: appRouting,
            connectUseCase: connectUseCase,
            sessionUseCase: sessionUseCase
        )
        viewFactory.useCases = container
        return container
    }
}
