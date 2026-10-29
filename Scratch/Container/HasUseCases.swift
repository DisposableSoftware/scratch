// Single-requirement protocols that ViewModels compose into their `UseCases` typealias (ARCH-9).
// AppContainer conforms to all of them (ARCH-14), and every one belongs in AllUseCases.

protocol HasCoordinator {
    var coordinator: Coordinator { get }
}

protocol HasAppRoutingUseCase {
    var appRouting: AppRoutingUseCase { get }
}

typealias AllUseCases = HasCoordinator
    & HasAppRoutingUseCase
