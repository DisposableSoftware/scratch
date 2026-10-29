/// Moves between the app's screens: asks the Router for the next step, then has the Coordinator
/// show it (ARCH-11).
protocol AppRoutingUseCase {
    func navigateToNext(from step: AppStep, with data: AppFlowData) async
}

/// Builds the destination for a step.
protocol ViewFactory {
    func destination(for step: AppStep, with data: AppFlowData) -> NavigationDestination
}

struct DefaultAppRoutingUseCase: AppRoutingUseCase {
    let router: AppRouter
    let coordinator: Coordinator
    let viewFactory: ViewFactory

    func navigateToNext(from step: AppStep, with data: AppFlowData) async {
        guard let next = router.nextStep(from: step, with: data) else { return }

        let destination = viewFactory.destination(for: next, with: data)
        await coordinator.navigateTo(destination)
    }
}
