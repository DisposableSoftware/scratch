import Combine

enum SettingsAction: Equatable {
    case formatChanged(NetworkKind, StreamQuality.Format)
    case maxBitRateChanged(NetworkKind, Int?)
    case done
}

/// The settings sheet (LIB-6): transcoding per network (TRANS-1, TRANS-2, TRANS-3).
final class SettingsViewModel: ViewModel {
    typealias UseCases = HasTranscodingUseCase & HasCoordinator

    let useCases: UseCases

    @Published private(set) var transcoding: TranscodingSettings

    init(useCases: UseCases) {
        self.useCases = useCases
        transcoding = useCases.transcodingUseCase.settings
    }

    func handleAction(_ action: SettingsAction) async -> SideEffect {
        switch action {
        case .formatChanged(let network, let format):
            update(network) { $0.format = format }
        case .maxBitRateChanged(let network, let maxBitRate):
            update(network) { $0.maxBitRate = maxBitRate }
        case .done:
            await useCases.coordinator.navigateTo(.dismissSheet)
        }
        return .none
    }

    private func update(_ network: NetworkKind, _ change: (inout StreamQuality) -> Void) {
        switch network {
        case .wifi: change(&transcoding.wifi)
        case .cellular: change(&transcoding.cellular)
        }
        useCases.transcodingUseCase.update(transcoding)
    }
}
