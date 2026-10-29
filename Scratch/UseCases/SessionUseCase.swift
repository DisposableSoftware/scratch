/// The signed-in session: across launches (SRV-5), when the server stops accepting it (SRV-6),
/// and signing out (SRV-7).
protocol SessionUseCase {
    /// The server signed in to, for settings to show.
    var account: ServerAccount? { get }
    /// After the server rejected the saved credentials, the account to fill setup in with.
    var rejectedAccount: ServerAccount? { get }

    /// Signs in with the saved server, if there is one. Called once at launch.
    func restoreSavedServer()
    /// The server no longer accepts the saved credentials: sign out, remembering the account.
    func credentialsRejected()
    func signOut()
}

final class DefaultSessionUseCase: SessionUseCase {
    private let credentialGateway: CredentialGateway
    private let playback: PlaybackUseCase
    private let sessionState: SessionState
    private let libraryState: LibraryState
    private let albumsState: AlbumsState

    init(
        credentialGateway: CredentialGateway,
        playback: PlaybackUseCase,
        sessionState: SessionState,
        libraryState: LibraryState,
        albumsState: AlbumsState
    ) {
        self.credentialGateway = credentialGateway
        self.playback = playback
        self.sessionState = sessionState
        self.libraryState = libraryState
        self.albumsState = albumsState
    }

    var account: ServerAccount? { sessionState.server?.account }
    var rejectedAccount: ServerAccount? { sessionState.rejectedAccount }

    func restoreSavedServer() {
        sessionState.server = credentialGateway.load()
    }

    func credentialsRejected() {
        // Already signed out (a second rejection, or one after sign out): keep what's remembered.
        guard let account = sessionState.server?.account else { return }
        end()
        sessionState.rejectedAccount = account
    }

    func signOut() {
        end()
    }

    /// Stops playback, forgets the server and its tracks, and deletes what was saved. A Keychain
    /// that refuses the delete still leaves the app signed out: the gateway forgets the URL and
    /// username regardless.
    private func end() {
        playback.stop()
        try? credentialGateway.delete()
        sessionState.server = nil
        sessionState.rejectedAccount = nil
        libraryState.tracks = []
        libraryState.hasMoreTracks = true
        albumsState.albums = []
        albumsState.hasMoreAlbums = true
        albumsState.nextOffset = 0
    }
}
