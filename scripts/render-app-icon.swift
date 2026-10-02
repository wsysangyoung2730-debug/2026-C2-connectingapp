#!/usr/bin/env swift

// Reproducible, original PAPER artwork. No generated or third-party images are used.
// Run from the repository root with the active Xcode toolchain:
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/render-app-icon.swift
// The geometry mirrors NaldamLogo in App/NaldamDesign.swift at its 32-point size.

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum IconRenderError: Error {
    case couldNotCreateContext
    case couldNotCreateImage
    case couldNotCreateDestination
    case couldNotWritePNG
}

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "C2_connecting app/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
let pixelSize = 1024
let ivory = CGColor(srgbRed: 247 / 255, green: 243 / 255, blue: 236 / 255, alpha: 1)
let terracotta = CGColor(srgbRed: 178 / 255, green: 85 / 255, blue: 57 / 255, alpha: 1)

guard let context = CGContext(
    data: nil,
    width: pixelSize,
    height: pixelSize,
    bitsPerComponent: 8,
    bytesPerRow: pixelSize * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { throw IconRenderError.couldNotCreateContext }

context.setFillColor(ivory)
context.fill(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
context.setShouldAntialias(true)
context.setAllowsAntialiasing(true)

// Use SwiftUI's top-left coordinate system and an optical 600-point symbol.
context.translateBy(x: 0, y: CGFloat(pixelSize))
context.scaleBy(x: 1, y: -1)
let symbolHeight: CGFloat = 600
let symbolWidth = symbolHeight * 0.84
let origin = CGPoint(x: (CGFloat(pixelSize) - symbolWidth) / 2,
                     y: (CGFloat(pixelSize) - symbolHeight) / 2)
let smallRadius = symbolHeight * 7 / 32
let foldRadius = symbolHeight * 16 / 32
let cubic: CGFloat = 0.5522847498307936

let page = CGMutablePath()
page.move(to: CGPoint(x: origin.x + smallRadius, y: origin.y))
page.addLine(to: CGPoint(x: origin.x + symbolWidth - foldRadius, y: origin.y))
page.addCurve(
    to: CGPoint(x: origin.x + symbolWidth, y: origin.y + foldRadius),
    control1: CGPoint(x: origin.x + symbolWidth - foldRadius + foldRadius * cubic, y: origin.y),
    control2: CGPoint(x: origin.x + symbolWidth, y: origin.y + foldRadius - foldRadius * cubic)
)
page.addLine(to: CGPoint(x: origin.x + symbolWidth, y: origin.y + symbolHeight - smallRadius))
page.addCurve(
    to: CGPoint(x: origin.x + symbolWidth - smallRadius, y: origin.y + symbolHeight),
    control1: CGPoint(x: origin.x + symbolWidth, y: origin.y + symbolHeight - smallRadius + smallRadius * cubic),
    control2: CGPoint(x: origin.x + symbolWidth - smallRadius + smallRadius * cubic, y: origin.y + symbolHeight)
)
page.addLine(to: CGPoint(x: origin.x + smallRadius, y: origin.y + symbolHeight))
page.addCurve(
    to: CGPoint(x: origin.x, y: origin.y + symbolHeight - smallRadius),
    control1: CGPoint(x: origin.x + smallRadius - smallRadius * cubic, y: origin.y + symbolHeight),
    control2: CGPoint(x: origin.x, y: origin.y + symbolHeight - smallRadius + smallRadius * cubic)
)
page.addLine(to: CGPoint(x: origin.x, y: origin.y + smallRadius))
page.addCurve(
    to: CGPoint(x: origin.x + smallRadius, y: origin.y),
    control1: CGPoint(x: origin.x, y: origin.y + smallRadius - smallRadius * cubic),
    control2: CGPoint(x: origin.x + smallRadius - smallRadius * cubic, y: origin.y)
)
page.closeSubpath()
context.setFillColor(terracotta)
context.addPath(page)
context.fillPath()

// This negative-space fold uses the exact diagonal/quadratic path from FoldShape.
let foldSize = symbolHeight * 0.44
let foldOrigin = CGPoint(x: origin.x + symbolWidth - foldSize, y: origin.y)
let fold = CGMutablePath()
fold.move(to: foldOrigin)
fold.addLine(to: CGPoint(x: foldOrigin.x + foldSize, y: foldOrigin.y + foldSize))
fold.addQuadCurve(
    to: CGPoint(x: foldOrigin.x, y: foldOrigin.y + foldSize * 0.75),
    control: CGPoint(x: foldOrigin.x, y: foldOrigin.y + foldSize * 1.05)
)
fold.closeSubpath()
context.setFillColor(ivory)
context.addPath(fold)
context.fillPath()

guard let image = context.makeImage() else { throw IconRenderError.couldNotCreateImage }
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { throw IconRenderError.couldNotCreateDestination }
CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGInterlaceType: 0]] as CFDictionary)
guard CGImageDestinationFinalize(destination) else { throw IconRenderError.couldNotWritePNG }

let bitmap = NSBitmapImageRep(cgImage: image)
precondition(!bitmap.hasAlpha, "App Store icons must be opaque.")
print("Rendered \(pixelSize)×\(pixelSize) opaque PAPER icon: \(outputURL.path)")
