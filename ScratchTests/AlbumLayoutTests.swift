import SwiftUI
import Testing
import UIKit
@testable import Scratch

private struct LayoutUseCases: HasAlbumUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasSessionUseCase, HasAppRoutingUseCase {
    let albumUseCase: AlbumUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
    let sessionUseCase: SessionUseCase
    let appRouting: AppRoutingUseCase
}

/// Draws the real album screen in a window, and reads the layout off the pixels, since a `List`'s
/// row insets can't be asked for. Needs the app as the test host.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AlbumLayoutTests {
    /// The leftmost and rightmost columns, in points, where a row of the picture differs from its background.
    private struct Edges {
        var leading: CGFloat
        var trailing: CGFloat
    }

    private func screen() async throws -> UIImage {
        let detail = AlbumDetail.numbered(discs: 1, perDisc: 12)
        let gateway = AlbumGatewayMock()
        gateway.details[detail.album.id] = detail
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        let viewModel = AlbumViewModel(album: detail.album, useCases: LayoutUseCases(albumUseCase: albums, coverArtUseCase: CoverArtUseCaseMock(), playbackUseCase: PlaybackUseCaseMock(), sessionUseCase: SessionUseCaseMock(), appRouting: AppRoutingUseCaseSpy()))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        return try #require(await WindowSnapshot.image(of: AlbumView(viewModel: viewModel), size: CGSize(width: 402, height: 1600)))
    }

    /// The edges of what is drawn in the rows `rows` (in points) of `image`.
    private func edges(of image: UIImage, rows: Range<Int>) throws -> Edges {
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width
        let data = try #require(cgImage.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let scale = Int(image.scale)

        func pixel(_ x: Int, _ y: Int) -> [Int] { (0..<3).map { Int(bytes[y * cgImage.bytesPerRow + x * bytesPerPixel + $0]) } }

        // The picture's left column is the window's background.
        var first = Int.max
        var last = -1
        for y in (rows.lowerBound * scale)..<(rows.upperBound * scale) {
            let background = pixel(0, y)

            for x in 0..<width {
                let colour = pixel(x, y)

                if zip(colour, background).map({ abs($0 - $1) }).reduce(0, +) > 30 {
                    first = min(first, x)
                    last = max(last, x)
                }
            }
        }

        return Edges(leading: CGFloat(first) / CGFloat(scale), trailing: CGFloat(width - 1 - last) / CGFloat(scale))
    }

    // ALB-19
    @Test func theTracksSitOnTheSameMarginsAsTheButtons() async throws {
        let image = try await screen()
        let directory = ProcessInfo.processInfo.environment["SCRATCH_SNAPSHOTS"]

        if let directory {
            try image.pngData()?.write(to: URL(fileURLWithPath: directory).appending(path: "alb19-album.png"))
        }

        // Rows of the 402 x 1600 pt picture: Play and Shuffle sit at about 600 pt, the twelve tracks below them.
        let buttons = try edges(of: image, rows: 600..<620)
        let tracks = try edges(of: image, rows: 650..<1260)

        withKnownIssue("ALB-19: fails until fixed") {
            #expect(abs(tracks.leading - buttons.leading) < 1, "tracks start \(tracks.leading) pt from the left, the buttons \(buttons.leading)")
            #expect(abs(tracks.trailing - buttons.trailing) < 1, "tracks end \(tracks.trailing) pt from the right, the buttons \(buttons.trailing)")
        }
    }
}
