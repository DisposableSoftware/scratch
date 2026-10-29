import Combine
import SwiftUI

enum AlbumsAction: Equatable {
    case settingsTapped
}

/// The Albums tab (ALB-2 to ALB-8).
final class AlbumsViewModel: RoutingViewModel {
    typealias UseCases = HasTranscodingUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case settings

        func destination(context: AlbumsViewModel) -> NavigationDestination {
            SettingsViewModel.destination(useCases: context.useCases)
        }
    }

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    init(useCases: UseCases) {
        self.useCases = useCases
    }

    func handleAction(_ action: AlbumsAction) async -> SideEffect {
        switch action {
        case .settingsTapped:
            await navigateTo(.settings)
        }
        return .none
    }
}
