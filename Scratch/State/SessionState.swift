import Combine

/// Who the app is signed in as. UseCases update it; the Router reads it.
final class SessionState: ObservableObject {
    @Published var account: ServerAccount?

    init(account: ServerAccount? = nil) {
        self.account = account
    }
}
