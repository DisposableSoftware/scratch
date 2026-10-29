import SwiftUI
import Testing
import UIKit
@testable import Scratch

private struct PlaylistLayoutUseCases: HasPlaylistUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasSessionUseCase, HasAppRoutingUseCase {
    let playlistUseCase: PlaylistUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
    let sessionUseCase: SessionUseCase
    let appRouting: AppRoutingUseCase
}

/// Draws the real playlist screen in a window and reads its margins off the pixels (PLST-9).
@Suite(.serialized, .timeLimit(.minutes(1)))
struct PlaylistLayoutTests {
    private func screen() async throws -> UIImage {
        var detail = PlaylistDetail.numbered(12)
        detail.tracks[1].isStarred = true
        let gateway = PlaylistGatewayMock()
        gateway.details[detail.playlist.id] = detail
        let playlists = DefaultPlaylistUseCase(playlistGateway: gateway, sessionState: SessionState(server: .sample))
        let viewModel = PlaylistViewModel(playlist: detail.playlist, useCases: PlaylistLayoutUseCases(playlistUseCase: playlists, coverArtUseCase: CoverArtUseCaseMock(), playbackUseCase: PlaybackUseCaseMock(), sessionUseCase: SessionUseCaseMock(), appRouting: AppRoutingUseCaseSpy()))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        return try #require(await WindowSnapshot.image(of: PlaylistView(viewModel: viewModel), size: CGSize(width: 402, height: 1600)))
    }

    /// The leftmost and rightmost columns, in points from each edge, where `rows` (in points) differ from the background.
    private func edges(of image: UIImage, rows: Range<Int>) throws -> (leading: CGFloat, trailing: CGFloat) {
        let scale = Int(image.scale)
        let width = Int(image.size.width) * scale
        var bytes = [UInt8](repeating: 0, count: width * Int(image.size.height) * scale * 4)
        let context = try #require(CGContext(data: &bytes, width: width, height: Int(image.size.height) * scale, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.draw(try #require(image.cgImage), in: CGRect(x: 0, y: 0, width: width, height: Int(image.size.height) * scale))

        func pixel(_ x: Int, _ y: Int) -> [Int] { (0..<3).map { Int(bytes[(y * width + x) * 4 + $0]) } }

        var first = Int.max
        var last = -1

        for y in (rows.lowerBound * scale)..<(rows.upperBound * scale) {
            let background = pixel(0, y)

            for x in 0..<width where zip(pixel(x, y), background).map({ abs($0 - $1) }).reduce(0, +) > 30 {
                first = min(first, x)
                last = max(last, x)
            }
        }

        return (CGFloat(first) / CGFloat(scale), CGFloat(width - 1 - last) / CGFloat(scale))
    }

    /// Whether anything is drawn in rows `rows` and columns `columns` (both in points) of `image`.
    private func isDrawn(in image: UIImage, rows: Range<Int>, columns: Range<Int>) throws -> Bool {
        let scale = Int(image.scale)
        let width = Int(image.size.width) * scale
        var bytes = [UInt8](repeating: 0, count: width * Int(image.size.height) * scale * 4)
        let context = try #require(CGContext(data: &bytes, width: width, height: Int(image.size.height) * scale, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.draw(try #require(image.cgImage), in: CGRect(x: 0, y: 0, width: width, height: Int(image.size.height) * scale))

        func pixel(_ x: Int, _ y: Int) -> [Int] { (0..<3).map { Int(bytes[(y * width + x) * 4 + $0]) } }

        for y in (rows.lowerBound * scale)..<(rows.upperBound * scale) {
            let background = pixel(0, y)

            for x in (columns.lowerBound * scale)..<(columns.upperBound * scale)
            where zip(pixel(x, y), background).map({ abs($0 - $1) }).reduce(0, +) > 30 {
                return true
            }
        }

        return false
    }

    // PLST-9
    @Test func theTracksSitOnTheSameMarginsAsTheButtons() async throws {
        let image = try await screen()

        if let directory = ProcessInfo.processInfo.environment["SCRATCH_SNAPSHOTS"] {
            try image.pngData()?.write(to: URL(fileURLWithPath: directory).appending(path: "plst9-playlist.png"))
        }

        // Rows of the 402 x 1600 pt picture: Play and Shuffle sit at about 560 pt (no artist line), the tracks below.
        let buttons = try edges(of: image, rows: 560..<580)
        let tracks = try edges(of: image, rows: 640..<1200)

        // Track 2 is starred: the gap left of its duration (326 to 346 pt) holds a heart, and track 1's doesn't.
        #expect(try isDrawn(in: image, rows: 705..<720, columns: 326..<346))
        #expect(try isDrawn(in: image, rows: 635..<650, columns: 326..<346) == false)
        #expect(abs(tracks.leading - buttons.leading) < 1, "tracks start \(tracks.leading) pt from the left, the buttons \(buttons.leading)")
        #expect(abs(tracks.trailing - buttons.trailing) < 1, "tracks end \(tracks.trailing) pt from the right, the buttons \(buttons.trailing)")
    }
}
