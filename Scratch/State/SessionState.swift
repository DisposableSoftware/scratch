import Combine

/// The server the app is signed in to. UseCases update it; the Router reads it.
final class SessionState: ObservableObject {
    @Published var server: SavedServer?

    init(server: SavedServer? = nil) {
        self.server = server
    }
}
