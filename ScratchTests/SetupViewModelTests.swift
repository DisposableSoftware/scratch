import Testing
@testable import Scratch

struct SetupViewModelTests {
    @Test func startsEmptyAndTakesEachField() async {
        let viewModel = SetupViewModel(useCases: AppContainer.build(coordinator: CoordinatorSpy()))
        #expect(viewModel.serverURL.isEmpty && viewModel.username.isEmpty && viewModel.password.isEmpty)

        _ = await viewModel.handleAction(.serverURLChanged("music.example.com"))
        _ = await viewModel.handleAction(.usernameChanged("me"))
        _ = await viewModel.handleAction(.passwordChanged("secret"))

        #expect(viewModel.serverURL == "music.example.com")
        #expect(viewModel.username == "me")
        #expect(viewModel.password == "secret")
    }
}
