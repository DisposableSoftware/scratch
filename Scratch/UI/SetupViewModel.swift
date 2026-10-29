import Combine

enum SetupAction: Equatable {
    case serverURLChanged(String)
    case usernameChanged(String)
    case passwordChanged(String)
    case connect
}

/// The setup screen: which server to use and who the user is (SRV-1), and connecting to it
/// (SRV-3).
final class SetupViewModel: ViewModel {
    typealias UseCases = HasConnectUseCase & HasAppRoutingUseCase

    let useCases: UseCases

    @Published private(set) var serverURL = ""
    @Published private(set) var username = ""
    @Published private(set) var password = ""
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?

    init(useCases: UseCases) {
        self.useCases = useCases
    }

    func handleAction(_ action: SetupAction) async -> SideEffect {
        switch action {
        case .serverURLChanged(let value):
            serverURL = value
        case .usernameChanged(let value):
            username = value
        case .passwordChanged(let value):
            password = value
        case .connect:
            await connect()
        }
        return .none
    }

    private func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }
        do {
            try await useCases.connectUseCase.connect(address: serverURL, username: username, password: password)
            await useCases.appRouting.navigateToNext(from: .setup, with: AppFlowData())
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: ConnectError) -> String {
        switch error {
        case .invalidAddress(.empty):
            "Enter the server's address."
        case .invalidAddress(.unsupportedScheme(let scheme)):
            "Scratch connects over http or https, not \(scheme)."
        case .invalidAddress:
            "That doesn't look like a server address. Try something like https://music.example.com."
        case .server(.unreachable):
            "Couldn't reach the server. Check the address, the port and your connection."
        case .server(.wrongCredentials):
            "Wrong username or password."
        case .server(.notSubsonic):
            "Something answered at that address, but it isn't a Navidrome or Subsonic server."
        case .server(.failed(_, let message)):
            message.isEmpty ? "The server refused the connection." : "The server said: \(message)"
        case .couldNotSave:
            "Connected, but the server couldn't be saved on this device. Try again."
        }
    }
}
