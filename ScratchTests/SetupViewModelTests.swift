import Testing
@testable import Scratch

private struct SetupUseCases: HasConnectUseCase, HasAppRoutingUseCase {
    let connectUseCase: ConnectUseCase
    let appRouting: AppRoutingUseCase
}

struct SetupViewModelTests {
    private let connect = ConnectUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()
    private var viewModel: SetupViewModel { SetupViewModel(useCases: SetupUseCases(connectUseCase: connect, appRouting: routing)) }

    @Test func startsEmptyAndTakesEachField() async {
        let viewModel = viewModel
        #expect(viewModel.serverURL.isEmpty && viewModel.username.isEmpty && viewModel.password.isEmpty)

        _ = await viewModel.handleAction(.serverURLChanged("music.example.com"))
        _ = await viewModel.handleAction(.usernameChanged("me"))
        _ = await viewModel.handleAction(.passwordChanged("secret"))

        #expect(viewModel.serverURL == "music.example.com")
        #expect(viewModel.username == "me")
        #expect(viewModel.password == "secret")
    }

    @Test func connectingPassesTheFieldsAndMovesOnFromSetup() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.serverURLChanged("music.example.com"))
        _ = await viewModel.handleAction(.usernameChanged("me"))
        _ = await viewModel.handleAction(.passwordChanged("secret"))

        _ = await viewModel.handleAction(.connect)

        #expect(connect.calls.count == 1)
        #expect(connect.calls.first?.address == "music.example.com")
        #expect(connect.calls.first?.username == "me")
        #expect(connect.calls.first?.password == "secret")
        #expect(routing.steps == [.setup])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isConnecting)
    }

    @Test(arguments: [
        (ConnectError.server(.unreachable), "Couldn't reach the server"),
        (ConnectError.server(.wrongCredentials), "Wrong username or password"),
        (ConnectError.server(.notSubsonic), "isn't a Navidrome or Subsonic server"),
        (ConnectError.invalidAddress(.empty), "Enter the server's address"),
        (ConnectError.server(.failed(code: 50, message: "Nope")), "The server said: Nope"),
    ])
    func aFailedConnectStaysOnSetupAndSaysWhy(error: ConnectError, expected: String) async {
        connect.error = error
        let viewModel = viewModel

        _ = await viewModel.handleAction(.connect)

        #expect(routing.steps.isEmpty)
        #expect(viewModel.errorMessage?.contains(expected) == true)
        #expect(!viewModel.isConnecting)
    }
}
