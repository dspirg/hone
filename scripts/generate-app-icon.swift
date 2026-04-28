#!/usr/bin/env swift
// generate-app-icon.swift
// Generates AppIcon-1024.png using CoreGraphics + CoreText.
// Design spec: bold "H" lettermark, amber-to-orange gradient, dark background.
//
// Run from the repo root:
//   swift Scripts/generate-app-icon.swift

import Foundation
import CoreGraphics
import ImageIO
import CoreText

// MARK: - Config

let size = 1024
let outputPath = "WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// Colors (linear; iOS applies sRGB gamma so we use device RGB for exact matching)
let bgR: CGFloat = 10.0 / 255.0   // #0a0a0a
let bgG: CGFloat = 10.0 / 255.0
let bgB: CGFloat = 10.0 / 255.0

let amberR: CGFloat = 245.0 / 255.0  // #f59e0b  (top)
let amberG: CGFloat = 158.0 / 255.0
let amberB: CGFloat = 11.0  / 255.0

let orangeR: CGFloat = 249.0 / 255.0  // #f97316  (bottom)
let orangeG: CGFloat = 115.0 / 255.0
let orangeB: CGFloat = 22.0  / 255.0

// MARK: - Create bitmap context (RGB, no alpha)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                                        | CGImageAlphaInfo.noneSkipLast.rawValue)

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    fputs("ERROR: Could not create CGContext\n", stderr)
    exit(1)
}

// CoreGraphics coordinate system: origin is bottom-left, Y increases upward.

// MARK: - Fill background

ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [bgR, bgG, bgB, 1.0])!)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// MARK: - Draw "H" glyph path using CTFont

// Target: H occupies ~58% of icon height → ~595pt, use a bold system font
// We scale the font so the capital-H height fills the target.
// Strategy:
//   1. Create font at large point size, measure the actual bounding box of "H".
//   2. Compute scale factor to hit target height.
//   3. Re-create scaled font, get the glyph path, translate to center.

func makeHPath(targetHeight: CGFloat) -> CGPath? {
    // Start with a large seed size; we'll scale.
    let seedSize: CGFloat = 600
    let fontName = "Helvetica-Bold" as CFString
    guard let font = CTFontCreateWithName(fontName, seedSize, nil) as CTFont? else {
        return nil
    }

    var glyph: CGGlyph = 0
    var char: UniChar = 0x0048  // 'H'
    guard CTFontGetGlyphsForCharacters(font, &char, &glyph, 1) else {
        return nil
    }

    // Measure bounding box at seed size
    var seedGlyph = glyph
    let bbox = CTFontGetBoundingRectsForGlyphs(font, .default, &seedGlyph, nil, 1)
    let seedHeight = bbox.height

    guard seedHeight > 0 else { return nil }

    let scale = targetHeight / seedHeight
    let finalSize = seedSize * scale

    guard let scaledFont = CTFontCreateWithName(fontName, finalSize, nil) as CTFont? else {
        return nil
    }

    var scaledGlyph = glyph
    guard let glyphPath = CTFontCreatePathForGlyph(scaledFont, scaledGlyph, nil) else {
        return nil
    }

    // Bounding box at final size
    let finalBbox = CTFontGetBoundingRectsForGlyphs(scaledFont, .default, &scaledGlyph, nil, 1)

    // Center the glyph on the 1024x1024 canvas
    let canvasCenter = CGFloat(size) / 2.0
    let tx = canvasCenter - (finalBbox.origin.x + finalBbox.width / 2.0)
    let ty = canvasCenter - (finalBbox.origin.y + finalBbox.height / 2.0)

    var transform = CGAffineTransform(translationX: tx, y: ty)
    guard let translatedPath = glyphPath.mutableCopy(using: &transform) else {
        return nil
    }
    return translatedPath
}

let targetH: CGFloat = CGFloat(size) * 0.58  // 58% of 1024 ≈ 594px

guard let hPath = makeHPath(targetHeight: targetH) else {
    fputs("ERROR: Could not create H glyph path\n", stderr)
    exit(1)
}

// MARK: - Clip to H path and draw gradient

ctx.saveGState()
ctx.addPath(hPath)
ctx.clip()

// Gradient: amber (#f59e0b) at top (y = size) → orange (#f97316) at bottom (y = 0)
// CoreGraphics Y: top of canvas is y = size (when origin is bottom-left).
let gradColors = [
    amberR,  amberG,  amberB,  1.0,   // top color
    orangeR, orangeG, orangeB, 1.0    // bottom color
] as [CGFloat]

guard let gradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: gradColors,
    locations: [0.0, 1.0],
    count: 2
) else {
    fputs("ERROR: Could not create gradient\n", stderr)
    exit(1)
}

// Draw from top of canvas (y=size) to bottom (y=0) — amber at top, orange at bottom
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: CGFloat(size) / 2, y: CGFloat(size)),  // top
    end:   CGPoint(x: CGFloat(size) / 2, y: 0),              // bottom
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

ctx.restoreGState()

// MARK: - Write PNG output

guard let cgImage = ctx.makeImage() else {
    fputs("ERROR: Could not create CGImage from context\n", stderr)
    exit(1)
}

let fileURL = URL(fileURLWithPath: outputPath)

// Ensure parent directory exists
let dir = fileURL.deletingLastPathComponent()
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, "public.png" as CFString, 1, nil) else {
    fputs("ERROR: Could not create image destination at \(outputPath)\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(dest, cgImage, nil)

guard CGImageDestinationFinalize(dest) else {
    fputs("ERROR: Could not write PNG to \(outputPath)\n", stderr)
    exit(1)
}

// Verify file was written
let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath)
let fileSize = (attrs?[.size] as? Int) ?? 0

print("SUCCESS: AppIcon-1024.png written to \(outputPath)")
print("  Size: \(fileSize) bytes (\(fileSize / 1024) KB)")
print("  Dimensions: \(size)x\(size) px, RGB no-alpha")
print("  Design: bold H lettermark, amber-to-orange gradient, #0a0a0a background")
