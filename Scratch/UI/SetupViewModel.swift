import Combine

enum SetupAction: Equatable {
    case serverURLChanged(String)
    case usernameChanged(String)
    case passwordChanged(String)
}

/// The setup screen: where the user says which server to use and who they are (SRV-1).
final class SetupViewModel: ViewModel {
    typealias UseCases = HasCoordinator

    let useCases: UseCases

    @Published private(set) var serverURL = ""
    @Published private(set) var username = ""
    @Published private(set) var password = ""

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
        }
        return .none
    }
}
