import Foundation
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
        container = AppContainer.build(
            coordinator: coordinator,
            networkSession: URLSession.shared,
            environment: .live
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(presenter: presenter)
                .task {
                    // Unit tests run inside the app; it stays on its spinner, signed out and offline.
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                    container.sessionUseCase.restoreSavedServer()
                    await container.appRouting.navigateToNext(from: .launch, with: AppFlowData())
                }
        }
    }
}
