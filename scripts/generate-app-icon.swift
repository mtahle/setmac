#!/usr/bin/env swift
// Generates Resources/icon.png (1024×1024) — run with: swift scripts/generate-app-icon.swift
import AppKit

let iconSize: CGFloat = 1024
let cornerRadius: CGFloat = 220   // ~21.5 % — macOS Sequoia/Tahoe standard

let image = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // ── Rounded-rect clip ──────────────────────────────────────────────
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()

    // ── Background gradient (blue → indigo) ───────────────────────────
    let cs = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 0.11, green: 0.20, blue: 0.80, alpha: 1),
        CGColor(red: 0.36, green: 0.16, blue: 0.76, alpha: 1),
    ] as CFArray
    let locs: [CGFloat] = [0, 1]
    if let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: locs) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 0, y: iconSize),
            end: CGPoint(x: iconSize, y: 0),
            options: []
        )
    }

    // ── Decorative glow circles ───────────────────────────────────────
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.fillEllipse(in: CGRect(x: 560, y: 480, width: 580, height: 580))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.04))
    ctx.fillEllipse(in: CGRect(x: -80, y: -80, width: 400, height: 400))

    // ── ">_" monospaced terminal prompt ───────────────────────────────
    let font = NSFont.monospacedSystemFont(ofSize: 336, weight: .bold)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.shadowBlurRadius = 18
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.93),
        .shadow: shadow,
    ]
    let str = NSAttributedString(string: ">_", attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(
        x: (iconSize - sz.width)  / 2,
        y: (iconSize - sz.height) / 2 + 10
    ))

    return true
}

// ── Export PNG ────────────────────────────────────────────────────────
guard
    let tiff = image.tiffRepresentation,
    let rep  = NSBitmapImageRep(data: tiff),
    let png  = rep.representation(using: .png, properties: [:])
else {
    fputs("error: failed to render icon\n", stderr); exit(1)
}

let dest = URL(fileURLWithPath: "Resources/icon.png")
do {
    try png.write(to: dest)
    print("✓ icon written → \(dest.path)")
} catch {
    fputs("error: \(error)\n", stderr); exit(1)
}
