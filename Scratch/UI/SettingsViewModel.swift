import Combine
import Foundation

enum SettingsAction: Equatable {
    case formatChanged(NetworkKind, StreamQuality.Format)
    case maxBitRateChanged(NetworkKind, Int?)
    case signOut
    case done
}

/// The settings sheet (LIB-6): transcoding per network (TRANS-1, TRANS-2, TRANS-3), and the
/// server, with sign out (SRV-7).
final class SettingsViewModel: ViewModel {
    typealias UseCases = HasTranscodingUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    let useCases: UseCases

    @Published private(set) var transcoding: TranscodingSettings
    @Published private(set) var account: ServerAccount?

    init(useCases: UseCases) {
        self.useCases = useCases
        transcoding = useCases.transcodingUseCase.settings
        account = useCases.sessionUseCase.account
    }

    func handleAction(_ action: SettingsAction) async -> SideEffect {
        switch action {
        case .formatChanged(let network, let format):
            update(network) { $0.format = format }
        case .maxBitRateChanged(let network, let maxBitRate):
            update(network) { $0.maxBitRate = maxBitRate }
        case .signOut:
            // The Router takes a signed-out session to setup, which replaces the sheet too.
            useCases.sessionUseCase.signOut()
            account = nil
            await useCases.appRouting.navigateToNext(from: .library, with: AppFlowData())
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
