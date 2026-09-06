import AppKit
import CoreGraphics

// The plate, in miniature: night sky, the gilded day-arc, a horizon
// filament over the ground plane, and Fajr's six-petal rosette at the
// crest. Every colour is a token from SkyPalette.night.
func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let skyZenith: UInt32 = 0x0A0E28, groundTop: UInt32 = 0x0E1330, groundBottom: UInt32 = 0x141A3A, groundPlane: UInt32 = 0x0A0E26
let horizonWash: UInt32 = 0x232B5C, metal: UInt32 = 0xC9A96A, metalHighlight: UInt32 = 0xE8D5A3, leafGold: UInt32 = 0xD2AC5C
let keyline: UInt32 = 0x10163A, lapis: UInt32 = 0x39447F, glow: UInt32 = 0xF0D18B

func unit(_ deg: Double) -> CGPoint { CGPoint(x: cos(deg * .pi / 180), y: sin(deg * .pi / 180)) }

/// The design system's SixPetalRosette construction: each petal is the
/// vesica of two compass circles of radius r = tip / √3, centred at
/// ±30° from the petal's axis, so tip radius = r√3.
func rosettePath(center c: CGPoint, tipRadius: CGFloat) -> CGPath {
    let r = tipRadius / sqrt(3)
    let path = CGMutablePath()
    for k in 0..<6 {
        let phi = -90.0 + Double(k) * 60.0
        let c1 = CGPoint(x: c.x + r * unit(phi - 30).x, y: c.y + r * unit(phi - 30).y)
        let c2 = CGPoint(x: c.x + r * unit(phi + 30).x, y: c.y + r * unit(phi + 30).y)
        let samples = 48
        path.move(to: c)
        for i in 0...samples {  // circle 1: centre (phi+150) → tip (phi+30)
            let a = (phi + 150) - 120 * Double(i) / Double(samples)
            path.addLine(to: CGPoint(x: c1.x + r * unit(a).x, y: c1.y + r * unit(a).y))
        }
        for i in 0...samples {  // circle 2: tip (phi-30) → centre (phi-150)
            let a = (phi - 30) - 120 * Double(i) / Double(samples)
            path.addLine(to: CGPoint(x: c2.x + r * unit(a).x, y: c2.y + r * unit(a).y))
        }
        path.closeSubpath()
    }
    return path
}

func render(size: Int, inset: CGFloat, rosetteY: CGFloat, rosetteTip: CGFloat, to file: String) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let S = CGFloat(size)
    // CoreGraphics origin is bottom-left; flip so y grows downward like the app.
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

    // Sky: zenith at the top, deepening toward the horizon band.
    let sky = CGGradient(colorsSpace: space, colors: [hex(skyZenith), hex(groundTop), hex(groundBottom), hex(horizonWash)] as CFArray,
                         locations: [0, 0.45, 0.72, 0.80])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: S), options: [])

    // Ground plane below the horizon chord.
    let horizonY = S * (0.5 + 0.31 * inset) // 0.81 on iOS, pulled inward for the watch
    ctx.setFillColor(hex(groundPlane)); ctx.fill(CGRect(x: 0, y: horizonY, width: S, height: S - horizonY))

    // Star field: faint, deterministic, kept above the horizon.
    var seed: UInt64 = 0x1D5A_9C3E
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10_000) / 10_000 }
    for _ in 0..<70 {
        let x = rnd() * S, y = rnd() * horizonY * 0.9, r = 1.2 + rnd() * 2.2
        ctx.setFillColor(hex(0xECEEF5, 0.18 + rnd() * 0.32))
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    // The day-arc: a wide gilded curve whose crest carries the rosette,
    // fading toward the edges as the traversed gild does on the plate.
    let arcCenter = CGPoint(x: S / 2, y: rosetteY + S * 1.15)
    let arcRadius = S * 1.15
    let segments = 240
    ctx.setLineCap(.round)
    for i in 0..<segments {
        let t0 = CGFloat(i) / CGFloat(segments), t1 = CGFloat(i + 1) / CGFloat(segments)
        func point(_ t: CGFloat) -> CGPoint {
            let a = (-90 - 34 * inset) + 68 * inset * Double(t)
            return CGPoint(x: arcCenter.x + arcRadius * unit(a).x, y: arcCenter.y + arcRadius * unit(a).y)
        }
        let p0 = point(t0), p1 = point(t1)
        let edge = abs((p0.x + p1.x) / 2 - S / 2) / (S / 2)
        let alpha = max(0, 1 - pow(edge / inset, 1.6))
        ctx.setStrokeColor(hex(metal, alpha)); ctx.setLineWidth(S * 0.011)
        ctx.move(to: p0); ctx.addLine(to: p1); ctx.strokePath()
    }

    // Horizon filament, with the plate's brighter core.
    for (w, a, c) in [(S * 0.006, CGFloat(0.55), metal), (S * 0.0022, CGFloat(0.95), metalHighlight)] {
        let filament = CGGradient(colorsSpace: space, colors: [hex(c, 0), hex(c, a), hex(c, a), hex(c, 0)] as CFArray,
                                  locations: [0, 0.28, 0.72, 1])!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: S * (0.5 - 0.5 * inset), y: horizonY - w / 2, width: S * inset, height: w))
        ctx.drawLinearGradient(filament, start: CGPoint(x: S * (0.5 - 0.5 * inset), y: 0), end: CGPoint(x: S * (0.5 + 0.5 * inset), y: 0), options: [])
        ctx.restoreGState()
    }

    // Glow behind the rosette: the lit marker's halo.
    let rc = CGPoint(x: S / 2, y: rosetteY)
    let halo = CGGradient(colorsSpace: space, colors: [hex(glow, 0.55), hex(glow, 0.16), hex(glow, 0)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(halo, startCenter: rc, startRadius: 0, endCenter: rc, endRadius: rosetteTip * 1.9, options: [])

    // Rosette: gilded fill with a highlight toward the top, keyline edge, lapis core.
    let outer = rosettePath(center: rc, tipRadius: rosetteTip)
    ctx.saveGState(); ctx.addPath(outer); ctx.clip()
    let gild = CGGradient(colorsSpace: space, colors: [hex(metalHighlight), hex(leafGold), hex(metal)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gild, start: CGPoint(x: 0, y: rc.y - rosetteTip), end: CGPoint(x: 0, y: rc.y + rosetteTip), options: [])
    ctx.restoreGState()
    ctx.addPath(outer); ctx.setStrokeColor(hex(keyline, 0.85)); ctx.setLineWidth(S * 0.0045); ctx.strokePath()
    let core = rosettePath(center: rc, tipRadius: rosetteTip * 0.5)
    ctx.addPath(core); ctx.setFillColor(hex(lapis)); ctx.fillPath()
    ctx.addPath(core); ctx.setStrokeColor(hex(keyline, 0.7)); ctx.setLineWidth(S * 0.003); ctx.strokePath()
    let dot = rosetteTip * 0.06
    ctx.setFillColor(hex(metalHighlight)); ctx.fillEllipse(in: CGRect(x: rc.x - dot, y: rc.y - dot, width: dot * 2, height: dot * 2))

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: file))
    print("wrote \(file)")
}

let out = CommandLine.arguments[1]
// iOS: full-bleed square; the rosette sits high on the crest.
render(size: 1024, inset: 1.0, rosetteY: 430, rosetteTip: 215, to: out + "/AppIcon-1024.png")
// watchOS: the system masks a circle, so the composition pulls inward and centres.
render(size: 1024, inset: 0.78, rosetteY: 455, rosetteTip: 205, to: out + "/AppIcon-watch-1024.png")
