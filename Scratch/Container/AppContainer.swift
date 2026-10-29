import Foundation

/// The composition root: the only place concrete UseCases, Gateways, Routers and RoutingUseCases
/// are built (ARCH-14).
struct AppContainer: AllUseCases {
    let coordinator: Coordinator
    let appRouting: AppRoutingUseCase
    let connectUseCase: ConnectUseCase
    let sessionUseCase: SessionUseCase
    let libraryUseCase: LibraryUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
    let transcodingUseCase: TranscodingUseCase
    let albumUseCase: AlbumUseCase
    let displayUseCase: DisplayUseCase
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
        let libraryState = LibraryState()
        let albumsState = AlbumsState()
        let displayState = DisplayState()
        let playbackState = PlaybackState()

        // 2. Gateways
        let serverGateway = RemoteServerGateway(networkSession: networkSession)
        let credentialGateway = KeychainCredentialGateway(environment: environment)
        let libraryGateway = RemoteLibraryGateway(networkSession: networkSession)
        let albumGateway = RemoteAlbumGateway(networkSession: networkSession)
        let coverArtGateway = RemoteCoverArtGateway(networkSession: networkSession)
        let audioPlayer = AVPlayerAudioGateway()
        let nowPlaying = MPNowPlayingGateway()
        let settingsGateway = UserDefaultsSettingsGateway(environment: environment)
        let networkGateway = PathMonitorNetworkGateway()

        // 3. UseCases
        let connectUseCase = DefaultConnectUseCase(
            serverGateway: serverGateway,
            credentialGateway: credentialGateway,
            sessionState: sessionState
        )
        let libraryUseCase = DefaultLibraryUseCase(
            libraryGateway: libraryGateway,
            sessionState: sessionState,
            libraryState: libraryState
        )
        let albumUseCase = DefaultAlbumUseCase(
            albumGateway: albumGateway,
            sessionState: sessionState,
            albumsState: albumsState
        )
        let displayUseCase = DefaultDisplayUseCase(settingsGateway: settingsGateway, displayState: displayState)
        let coverArtUseCase = DefaultCoverArtUseCase(coverArtGateway: coverArtGateway, sessionState: sessionState)
        let transcodingUseCase = DefaultTranscodingUseCase(settingsGateway: settingsGateway, networkGateway: networkGateway)
        let playbackUseCase = DefaultPlaybackUseCase(
            audioPlayer: audioPlayer,
            nowPlaying: nowPlaying,
            transcoding: transcodingUseCase,
            sessionState: sessionState,
            playbackState: playbackState
        )
        let sessionUseCase = DefaultSessionUseCase(
            credentialGateway: credentialGateway,
            playback: playbackUseCase,
            sessionState: sessionState,
            libraryState: libraryState,
            albumsState: albumsState
        )

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
            sessionUseCase: sessionUseCase,
            libraryUseCase: libraryUseCase,
            coverArtUseCase: coverArtUseCase,
            playbackUseCase: playbackUseCase,
            transcodingUseCase: transcodingUseCase,
            albumUseCase: albumUseCase,
            displayUseCase: displayUseCase
        )
        viewFactory.useCases = container
        return container
    }
}
