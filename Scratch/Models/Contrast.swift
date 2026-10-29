import Foundation

/// Picks the colour for text drawn on an accent (LOOK-9).
nonisolated enum Contrast {
    /// Mocha's crust, the darkest of the palette.
    static let dark: UInt32 = 0x11111b
    static let light: UInt32 = 0xffffff

    /// WCAG contrast ratio of two 0xRRGGBB colours, from 1 to 21.
    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let (high, low) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))

        return (high + 0.05) / (low + 0.05)
    }

    /// Whichever of `dark` and `light` reads better on `background`: always at least 4.5:1.
    static func label(on background: UInt32) -> UInt32 {
        ratio(dark, background) >= ratio(light, background) ? dark : light
    }

    private static func luminance(_ hex: UInt32) -> Double {
        let channels = [(hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff].map { value -> Double in
            let channel = Double(value) / 255

            return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
