import SwiftUI

/// Builds each step's screen with the ViewModel it needs. The Container hands it the use cases
/// once they exist, because the routing use case it belongs to is part of them.
final class AppViewFactory: ViewFactory {
    var useCases: AllUseCases?

    func destination(for step: AppStep, with data: AppFlowData) -> NavigationDestination {
        guard let useCases else {
            assertionFailure("AppViewFactory used before AppContainer.build finished")
            return .root(AnyView(ProgressView()))
        }
        switch step {
        case .launch:
            return .root(AnyView(ProgressView()))
        case .setup:
            return .root(AnyView(SetupView(viewModel: SetupViewModel(useCases: useCases))))
        case .library:
            return .root(AnyView(MainView(
                viewModel: PlayerViewModel(useCases: useCases),
                albums: AlbumsView(viewModel: AlbumsViewModel(useCases: useCases)),
                songs: LibraryView(viewModel: LibraryViewModel(useCases: useCases))
            )))
        }
    }
}
