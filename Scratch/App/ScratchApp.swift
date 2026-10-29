import SwiftUI

@main
struct ScratchApp: App {
    @StateObject private var presenter: RootPresenter
    private let container: AppContainer

    init() {
        let presenter = RootPresenter()
        let coordinator = AppCoordinator()
        coordinator.register(presenter)
        _presenter = StateObject(wrappedValue: presenter)
        container = AppContainer.build(coordinator: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView(presenter: presenter)
        }
    }
}
