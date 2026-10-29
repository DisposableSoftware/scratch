import Foundation
import Testing
@testable import Scratch

private struct AlbumsUseCases: HasTranscodingUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))
struct AlbumsViewModelTests {
    @Test func theSettingsButtonOpensSettingsAsASheet() async {
        let coordinator = CoordinatorSpy()
        let viewModel = AlbumsViewModel(useCases: AlbumsUseCases(coordinator: coordinator))

        _ = await viewModel.handleAction(.settingsTapped)

        guard case .sheet = coordinator.destinations.last else {
            Issue.record("expected a sheet, got \(coordinator.destinations)")
            return
        }
    }
}
