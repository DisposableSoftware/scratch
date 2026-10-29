import SwiftUI
import Testing
import UIKit
@testable import Scratch

/// Draws the fallback cover and reads it off the pixels (LOOK-10).
@Suite(.timeLimit(.minutes(1)))
struct CoverArtTests {
    /// The picture of the fallback at `side` points, as RGB bytes: the tile fills the picture.
    private func picture(side: CGFloat, theme: Theme) throws -> (bytes: [UInt8], width: Int) {
        let renderer = ImageRenderer(content: CoverArt(image: nil).frame(width: side, height: side).environment(\.theme, theme))
        renderer.scale = 3
        let image = try #require(renderer.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        return (bytes, image.width)
    }

    private func hex(_ bytes: [UInt8], _ x: Int, _ y: Int, _ width: Int) -> UInt32 {
        let offset = (y * width + x) * 4

        return UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2])
    }

    @Test(arguments: [(Flavour.mocha, Accent.mauve), (.latte, .yellow), (.latte, .blue), (.frappe, .peach)], [CGFloat(48), 360])
    func theFallbackIsTheAccentWithANoteThatReads(pair: (Flavour, Accent), side: CGFloat) throws {
        let (flavour, accent) = pair
        let (bytes, width) = try picture(side: side, theme: Theme(flavour: flavour, accent: accent))
        let fill = Palette.hex(accent, in: flavour)

        // The tile is the accent, a little in from its rounded corner.
        let inset = Int(8 * 3)

        #expect(hex(bytes, inset, inset, width) == fill, "\(flavour)/\(accent) at \(side) pt")

        // The note is everything that isn't the fill: it is about half the tile wide and reads on it.
        var left = Int.max
        var right = -1

        for y in inset..<(width - inset) {
            for x in inset..<(width - inset) where hex(bytes, x, y, width) != fill {
                left = min(left, x)
                right = max(right, x)
            }
        }

        let noteWidth = Double(right - left + 1) / Double(width)

        #expect(noteWidth > 0.4 && noteWidth < 0.6, "the note is \(noteWidth) of the tile wide")

        // The ink is the pixel furthest from the fill.
        var ink = fill

        for y in inset..<(width - inset) {
            for x in inset..<(width - inset) {
                let colour = hex(bytes, x, y, width)

                if Contrast.ratio(colour, fill) > Contrast.ratio(ink, fill) { ink = colour }
            }
        }

        #expect(Contrast.ratio(ink, fill) >= 4.5, "the note's contrast is \(Contrast.ratio(ink, fill))")
    }
}
