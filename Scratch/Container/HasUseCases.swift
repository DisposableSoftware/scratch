// Single-requirement protocols that ViewModels compose into their `UseCases` typealias (ARCH-9).
// AppContainer conforms to all of them (ARCH-14), and every one belongs in AllUseCases.

protocol HasCoordinator {
    var coordinator: Coordinator { get }
}

protocol HasAppRoutingUseCase {
    var appRouting: AppRoutingUseCase { get }
}

protocol HasConnectUseCase {
    var connectUseCase: ConnectUseCase { get }
}

protocol HasSessionUseCase {
    var sessionUseCase: SessionUseCase { get }
}

protocol HasLibraryUseCase {
    var libraryUseCase: LibraryUseCase { get }
}

protocol HasCoverArtUseCase {
    var coverArtUseCase: CoverArtUseCase { get }
}

typealias AllUseCases = HasCoordinator
    & HasAppRoutingUseCase
    & HasConnectUseCase
    & HasSessionUseCase
    & HasLibraryUseCase
    & HasCoverArtUseCase
