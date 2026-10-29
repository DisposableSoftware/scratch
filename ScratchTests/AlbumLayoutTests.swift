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
@Suite(.serialized, .timeLimit(.minutes(3)))
struct AlbumLayoutTests {
    /// The leftmost and rightmost columns, in points, where a row of the picture differs from its background.
    private struct Edges {
        var leading: CGFloat
        var trailing: CGFloat
    }

    private func screen(theme: Theme? = nil) async throws -> UIImage {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 12)
        detail.tracks[1].track.isStarred = true
        detail.tracks[10].track.isStarred = true
        let gateway = AlbumGatewayMock()
        gateway.details[detail.album.id] = detail
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        let viewModel = AlbumViewModel(album: detail.album, useCases: LayoutUseCases(albumUseCase: albums, coverArtUseCase: CoverArtUseCaseMock(), playbackUseCase: PlaybackUseCaseMock(), sessionUseCase: SessionUseCaseMock(), appRouting: AppRoutingUseCaseSpy()))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        return try #require(await WindowSnapshot.image(of: AlbumView(viewModel: viewModel), size: CGSize(width: 402, height: 1600), theme: theme))
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

    /// Whether anything is drawn in rows `rows` and columns `columns` (both in points) of `image`.
    private func isDrawn(in image: UIImage, rows: Range<Int>, columns: Range<Int>) throws -> Bool {
        let cgImage = try #require(image.cgImage)
        let data = try #require(cgImage.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let scale = Int(image.scale)

        func pixel(_ x: Int, _ y: Int) -> [Int] { (0..<3).map { Int(bytes[y * cgImage.bytesPerRow + x * bytesPerPixel + $0]) } }

        for y in (rows.lowerBound * scale)..<(rows.upperBound * scale) {
            let background = pixel(0, y)

            for x in (columns.lowerBound * scale)..<(columns.upperBound * scale)
            where zip(pixel(x, y), background).map({ abs($0 - $1) }).reduce(0, +) > 30 {
                return true
            }
        }

        return false
    }

    // ALB-19, ALB-20: two of the twelve tracks are starred, and still end on the margin.
    @Test func theTracksSitOnTheSameMarginsAsTheButtons() async throws {
        let image = try await screen()
        let directory = ProcessInfo.processInfo.environment["SCRATCH_SNAPSHOTS"]

        if let directory {
            try image.pngData()?.write(to: URL(fileURLWithPath: directory).appending(path: "alb19-album.png"))
        }

        // Rows of the 402 x 1600 pt picture: Play and Shuffle sit at about 600 pt, the twelve tracks below them.
        let buttons = try edges(of: image, rows: 600..<620)
        let tracks = try edges(of: image, rows: 650..<1260)

        // Tracks 2 and 11 are starred: the gap left of the duration (326 to 346 pt) holds a heart in their rows only.
        #expect(try isDrawn(in: image, rows: 705..<720, columns: 326..<346))
        #expect(try isDrawn(in: image, rows: 653..<668, columns: 326..<346) == false)
        #expect(abs(tracks.leading - buttons.leading) < 1, "tracks start \(tracks.leading) pt from the left, the buttons \(buttons.leading)")
        #expect(abs(tracks.trailing - buttons.trailing) < 1, "tracks end \(tracks.trailing) pt from the right, the buttons \(buttons.trailing)")
    }

    /// WCAG contrast ratio of two sRGB colours, as (red, green, blue) in 0...255.
    private func contrast(_ first: [Int], _ second: [Int]) -> Double {
        func luminance(_ colour: [Int]) -> Double {
            let linear = colour.map { value -> Double in
                let channel = Double(value) / 255

                return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }

            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }

        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))

        return (lighter + 0.05) / (darker + 0.05)
    }

    // LOOK-9: the Play label against its button, read off the real screen in every flavour and accent.
    @Test func thePlayLabelIsReadableOnEveryAccent() async throws {
        var unreadable: [String] = []

        for flavour in Flavour.allCases {
            for accent in Accent.allCases {
                let image = try await screen(theme: Theme(flavour: flavour, accent: accent))
                let scale = Int(image.scale)
                let width = Int(image.size.width) * scale
                var bytes = [UInt8](repeating: 0, count: width * Int(image.size.height) * scale * 4)
                let context = try #require(CGContext(data: &bytes, width: width, height: Int(image.size.height) * scale, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
                context.draw(try #require(image.cgImage), in: CGRect(x: 0, y: 0, width: width, height: Int(image.size.height) * scale))

                do {
                    func pixel(_ x: Int, _ y: Int) -> [Int] { (0..<3).map { Int(bytes[(y * scale * width + x * scale) * 4 + $0]) } }

                    // The fill is read left of the label; the label's ink is the pixel furthest from it.
                    let fill = pixel(22, 609)
                    var ink = fill

                    for y in 598..<620 {
                        for x in 60..<140 where zip(pixel(x, y), fill).map({ abs($0 - $1) }).reduce(0, +) > zip(ink, fill).map({ abs($0 - $1) }).reduce(0, +) {
                            ink = pixel(x, y)
                        }
                    }

                    if contrast(fill, ink) < 4.5 {
                        unreadable.append("\(flavour)/\(accent) \(String(format: "%.1f", contrast(fill, ink))) fill \(fill) ink \(ink)")
                    }
                }
            }
        }

        #expect(unreadable.isEmpty, "Play's label is under 4.5:1 on: \(unreadable.joined(separator: ", "))")
    }
}
