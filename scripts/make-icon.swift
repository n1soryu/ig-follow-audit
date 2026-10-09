// Renders Resources/AppIcon.icns from the Lucide "user-round-search" glyph
// (ISC license, see Resources/Icon/LUCIDE-LICENSE.txt) on a gradient tile.
//
//   swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let glyphSVG = try String(contentsOf: root.appendingPathComponent("Resources/Icon/user-round-search.svg"), encoding: .utf8)

// The glyph's shapes, without its <svg> wrapper.
let glyph = glyphSVG
    .components(separatedBy: "\n")
    .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("<circle") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("<path") }
    .joined(separator: "\n")

// macOS icon grid: 824pt tile centred on a 1024pt canvas.
let glyphScale = 22.0
let iconSVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7B4DFF"/>
      <stop offset="0.55" stop-color="#E5397A"/>
      <stop offset="1" stop-color="#FF9A3D"/>
    </linearGradient>
    <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.28"/>
      <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#shine)"/>
  <g transform="translate(\(512 - 12 * glyphScale) \(512 - 12 * glyphScale)) scale(\(glyphScale))"
     fill="none" stroke="#FFFFFF" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
\(glyph)
  </g>
</svg>
"""

guard let image = NSImage(data: Data(iconSVG.utf8)) else { fatalError("Couldn't render the icon SVG") }

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = Double(size) / 1024
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.set()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try png(size: 1024).write(to: root.appendingPathComponent("Resources/Icon/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
