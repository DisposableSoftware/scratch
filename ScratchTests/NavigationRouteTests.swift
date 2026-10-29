import Combine
import SwiftUI
import Testing
@testable import Scratch

/// A ViewModel shaped like the note's CartViewModel, with a `Has*` composition for its UseCases.
private final class SampleViewModel: RoutingViewModel {
    typealias UseCases = HasCoordinator
    enum Action { case openDetail }
    enum Route: NavigationRoute {
        case detail

        func destination(context: SampleViewModel) -> NavigationDestination {
            .sheet(AnyView(Text("Detail")))
        }
    }

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    init(useCases: UseCases) {
        self.useCases = useCases
    }

    func handleAction(_ action: Action) async -> SideEffect {
        await navigateTo(.detail)
        return .none
    }
}

struct NavigationRouteTests {
    @Test func aViewModelRouteReachesTheCoordinator() async {
        let coordinator = CoordinatorSpy()
        let viewModel = SampleViewModel(useCases: AppContainer.build(coordinator: coordinator))

        _ = await viewModel.handleAction(.openDetail)

        #expect(coordinator.destinations.count == 1)
        guard case .sheet = coordinator.destinations.first else {
            Issue.record("expected a sheet, got \(coordinator.destinations)")
            return
        }
    }
}
