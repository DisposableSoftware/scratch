import SwiftUI
import Testing
@testable import Scratch

/// Records the steps it is asked for and answers each with a sheet.
private final class ViewFactorySpy: ViewFactory {
    private(set) var steps: [AppStep] = []

    func destination(for step: AppStep, with data: AppFlowData) -> NavigationDestination {
        steps.append(step)
        return .sheet(AnyView(EmptyView()))
    }
}

struct AppRoutingUseCaseTests {
    @Test func navigatesToTheStepTheRouterPicks() async {
        let coordinator = CoordinatorSpy()
        let factory = ViewFactorySpy()
        let routing = DefaultAppRoutingUseCase(
            router: AppRouter(sessionState: SessionState()),
            coordinator: coordinator,
            viewFactory: factory
        )

        await routing.navigateToNext(from: .launch, with: AppFlowData())

        #expect(factory.steps == [.setup])
        #expect(coordinator.destinations.count == 1)
    }

    @Test func staysPutWhenTheRouterHasNoNextStep() async {
        let coordinator = CoordinatorSpy()
        let factory = ViewFactorySpy()
        let routing = DefaultAppRoutingUseCase(
            router: AppRouter(sessionState: SessionState()),
            coordinator: coordinator,
            viewFactory: factory
        )

        await routing.navigateToNext(from: .setup, with: AppFlowData())

        #expect(factory.steps.isEmpty)
        #expect(coordinator.destinations.isEmpty)
    }
}
