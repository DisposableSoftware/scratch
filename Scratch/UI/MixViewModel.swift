import Combine
import Foundation
import SwiftUI
import UIKit

enum MixAction: Equatable {
    case trackTapped(Int)
    case playTapped
    case shuffleTapped
    case artworkNeeded(pixelSize: Int)
}

/// One mix's screen (MIX-10, MIX-11): its name, description, Play, and the tracks in order. The
/// mix is the phone's own copy, so there is nothing to load.
final class MixViewModel: ViewModel {
    typealias UseCases = HasCoverArtUseCase & HasPlaybackUseCase

    let useCases: UseCases
    let mix: Mix

    @Published private(set) var rows: [PlaylistRow]
    @Published private(set) var cover: UIImage?

    private var heldCoverSize = 0
    private var wantedCoverSize = 0
    private var fetchingCover = false

    init(mix: Mix, useCases: UseCases) {
        self.mix = mix
        self.useCases = useCases
        rows = PlaylistViewModel.rows(for: mix.tracks)
    }

    func handleAction(_ action: MixAction) async -> SideEffect {
        switch action {
        case .trackTapped(let index):
            // MIX-11: it plays, and what follows it in the mix is queued.
            if mix.tracks.indices.contains(index) { useCases.playbackUseCase.play(mix.tracks, startingAt: index) }
        case .playTapped:
            if !mix.tracks.isEmpty { useCases.playbackUseCase.play(mix.tracks, startingAt: 0) }
        case .shuffleTapped:
            if !mix.tracks.isEmpty { useCases.playbackUseCase.playShuffled(mix.tracks) }
        case .artworkNeeded(let pixelSize):
            await loadCover(pixelSize: pixelSize)
        }

        return .none
    }

    /// The first track's cover, fetched at the size the screen shows it, as the album screen does.
    private func loadCover(pixelSize: Int) async {
        guard let id = mix.tracks.first?.coverArtID else { return }

        wantedCoverSize = max(wantedCoverSize, pixelSize)
        guard !fetchingCover else { return }

        fetchingCover = true
        defer { fetchingCover = false }

        while Double(heldCoverSize) < Double(wantedCoverSize) * 0.95 {
            let target = wantedCoverSize
            guard let data = await useCases.coverArtUseCase.coverArt(id: id, pixelSize: target),
                  let image = await UIImage(data: data)?.byPreparingForDisplay()
            else { return }
            cover = image
            heldCoverSize = target
        }
    }
}
