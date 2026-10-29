import Foundation
import SwiftUI
import Testing
@testable import Scratch

struct PaletteTests {
    /// `design/catppuccin/<flavour>.css`, copies of the published palette, as name → 0xRRGGBB.
    private static func published(_ flavour: Flavour) throws -> [String: UInt32] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let css = try String(contentsOf: root.appending(path: "design/catppuccin/\(flavour.rawValue).css"), encoding: .utf8)
        var colours: [String: UInt32] = [:]

        for line in css.split(separator: "\n") where line.hasPrefix("@define-color ") {
            let parts = line.dropLast().split(separator: " ")

            colours[String(parts[1])] = UInt32(parts[2].dropFirst(), radix: 16)
        }

        return colours
    }

    // LOOK-9

    @Test(arguments: Flavour.allCases)
    func theLabelOnEveryAccentReadsAtFourAndAHalfToOne(flavour: Flavour) {
        for accent in Accent.allCases {
            let fill = Palette.hex(accent, in: flavour)

            #expect(Contrast.ratio(Contrast.label(on: fill), fill) >= 4.5, "\(flavour)/\(accent)")
        }
    }

    @Test func theRatioMatchesTheKnownExtremes() {
        #expect(abs(Contrast.ratio(0x000000, 0xffffff) - 21) < 0.01)
        #expect(Contrast.ratio(0x808080, 0x808080) == 1)
    }

    // LOOK-1, LOOK-2

    @Test(arguments: Flavour.allCases)
    func everyAccentIsThePublishedColour(flavour: Flavour) throws {
        let published = try Self.published(flavour)

        #expect(published.count == 26)

        for accent in Accent.allCases {
            #expect(Palette.hex(accent, in: flavour) == published[accent.rawValue], "\(flavour) \(accent)")
        }
    }

    // LOOK-3

    @Test(arguments: Flavour.allCases)
    func theRedIsThePublishedColour(flavour: Flavour) throws {
        #expect(Palette.red(in: flavour) == (try Self.published(flavour))["red"])
    }

    @Test func redIsKeptForErrorsAndIsNotAnAccentToPick() {
        #expect(Accent.allCases.count == 13 && !Accent.allCases.map(\.rawValue).contains("red"))
    }

    @Test func mochaWithMauveIsTheDefault() {
        #expect(Flavour.default == .mocha && Accent.default == .mauve)
        #expect(Palette.hex(.mauve, in: .mocha) == 0xcba6f7)
    }

    // LOOK-4

    @Test(arguments: [(Flavour.latte, false), (.frappe, true), (.macchiato, true), (.mocha, true)])
    func onlyLatteIsLight(flavour: Flavour, dark: Bool) {
        #expect(flavour.isDark == dark)
        #expect(Theme(flavour: flavour, accent: .mauve).colorScheme == (dark ? .dark : .light))
    }

    @Test func aThemeCarriesTheFlavoursAccentAndRed() {
        let theme = Theme(flavour: .latte, accent: .blue)

        #expect(theme.accent == Color(hex: 0x1e66f5))
        #expect(theme.error == Color(hex: 0xd20f39))
    }

    @Test func eachFlavourHasAName() {
        #expect(Flavour.allCases.map(\.label) == ["Latte", "Frappé", "Macchiato", "Mocha"])
        #expect(Accent.mauve.label == "Mauve")
    }
}
