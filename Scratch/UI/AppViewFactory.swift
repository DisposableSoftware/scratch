import SwiftUI

/// Builds each step's screen with the ViewModel it needs. The Container hands it the use cases
/// once they exist, because the routing use case it belongs to is part of them.
final class AppViewFactory: ViewFactory {
    var useCases: AllUseCases?
    var navigationStack: NavigationStackPort?

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
            let albums = AnyView(AlbumsView(viewModel: AlbumsViewModel(useCases: useCases)))
            let playlists = AnyView(PlaylistsView(viewModel: PlaylistsViewModel(useCases: useCases)))
            return .root(AnyView(MainView(
                viewModel: PlayerViewModel(useCases: useCases),
                albums: navigationStack?.stack(root: albums, pushing: "album") ?? albums,
                playlists: navigationStack?.stack(root: playlists, pushing: "playlist") ?? playlists,
                songs: LibraryView(viewModel: LibraryViewModel(useCases: useCases))
            )))
        }
    }
}
