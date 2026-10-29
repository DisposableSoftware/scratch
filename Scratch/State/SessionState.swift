import Combine

/// The server the app is signed in to. UseCases update it; the Router reads it.
final class SessionState: ObservableObject {
    @Published var server: SavedServer?
    /// The account whose credentials the server stopped accepting, for setup to fill in (SRV-6).
    @Published var rejectedAccount: ServerAccount?

    init(server: SavedServer? = nil) {
        self.server = server
    }
}
