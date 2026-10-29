import Combine
import Foundation

enum MainAction: Equatable {
    case lifecycle(LifecycleAction)

    /// The app came to the front: the model may have become available, or gone (MIX-1).
    case appBecameActive
}

/// The tab bar: whether the Me tab shows (MIX-1), and whether the now-playing bar does (PLAY-2).
final class MainViewModel: ViewModel {
    typealias UseCases = HasMixUseCase

    let useCases: UseCases

    /// The now-playing bar's ViewModel.
    let player: PlayerViewModel

    /// Whether the on-device model can make mixes, which is what the Me tab needs.
    @Published private(set) var showsMe: Bool

    /// Whether a track is loaded, which is when the bar shows.
    @Published private(set) var hasTrack = false

    init(player: PlayerViewModel, useCases: UseCases) {
        self.player = player
        self.useCases = useCases
        showsMe = useCases.mixUseCase.state.isModelAvailable
        useCases.mixUseCase.state.$isModelAvailable.assign(to: &$showsMe)
        player.$track.map { $0 != nil }.removeDuplicates().assign(to: &$hasTrack)
    }

    func handleAction(_ action: MainAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear), .appBecameActive:
            useCases.mixUseCase.refreshAvailability()
        }

        return .none
    }
}
