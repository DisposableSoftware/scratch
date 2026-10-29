#!/usr/bin/env bash
# Renders design/AppIcon.svg to the app's 1024x1024 icon (LOOK-8): macOS only. iOS wants no alpha
# channel, so the render is redrawn into an opaque bitmap.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
qlmanage -t -s 1024 -o "$tmp" design/AppIcon.svg >/dev/null 2>&1
swift - "$tmp/AppIcon.svg.png" Scratch/Assets.xcassets/AppIcon.appiconset/AppIcon.png <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let paths = CommandLine.arguments
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: paths[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: paths[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("could not render the icon") }

context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write the icon") }
SWIFT
