/// The signed-in session across launches (SRV-5).
protocol SessionUseCase {
    /// Signs in with the saved server, if there is one. Called once at launch.
    func restoreSavedServer()
}

final class DefaultSessionUseCase: SessionUseCase {
    private let credentialGateway: CredentialGateway
    private let sessionState: SessionState

    init(credentialGateway: CredentialGateway, sessionState: SessionState) {
        self.credentialGateway = credentialGateway
        self.sessionState = sessionState
    }

    func restoreSavedServer() {
        sessionState.server = credentialGateway.load()
    }
}
