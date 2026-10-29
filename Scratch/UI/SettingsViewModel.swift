import Combine
import Foundation
import SwiftUI

enum SettingsAction: Equatable {
    case formatChanged(NetworkKind, StreamQuality.Format)
    case maxBitRateChanged(NetworkKind, Int?)
    case albumsPerRowChanged(Int)
    case flavourChanged(Flavour)
    case accentChanged(Accent)
    case signOut
    case done
}

/// The settings sheet (LIB-6): transcoding per network (TRANS-1, TRANS-2, TRANS-3), the albums per
/// row, the flavour and accent (LOOK-5), and the server, with sign out (SRV-7).
final class SettingsViewModel: ViewModel {
    typealias UseCases = HasTranscodingUseCase & HasDisplayUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    let useCases: UseCases

    /// The settings sheet, as a destination, for the Route of every screen with a settings button.
    static func destination(useCases: UseCases) -> NavigationDestination {
        .sheet(AnyView(SettingsView(viewModel: SettingsViewModel(useCases: useCases))))
    }

    @Published private(set) var transcoding: TranscodingSettings
    @Published private(set) var account: ServerAccount?
    @Published private(set) var albumsPerRow: Int
    @Published private(set) var flavour: Flavour
    @Published private(set) var accent: Accent

    init(useCases: UseCases) {
        self.useCases = useCases
        transcoding = useCases.transcodingUseCase.settings
        account = useCases.sessionUseCase.account
        albumsPerRow = useCases.displayUseCase.state.albumsPerRow
        flavour = useCases.displayUseCase.state.flavour
        accent = useCases.displayUseCase.state.accent
        useCases.displayUseCase.state.$albumsPerRow.assign(to: &$albumsPerRow)
        useCases.displayUseCase.state.$flavour.assign(to: &$flavour)
        useCases.displayUseCase.state.$accent.assign(to: &$accent)
    }

    func handleAction(_ action: SettingsAction) async -> SideEffect {
        switch action {
        case .formatChanged(let network, let format):
            update(network) { $0.format = format }
        case .maxBitRateChanged(let network, let maxBitRate):
            update(network) { $0.maxBitRate = maxBitRate }
        case .albumsPerRowChanged(let count):
            useCases.displayUseCase.setAlbumsPerRow(count)
        case .flavourChanged(let flavour):
            useCases.displayUseCase.setFlavour(flavour)
        case .accentChanged(let accent):
            useCases.displayUseCase.setAccent(accent)
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
