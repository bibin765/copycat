import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

// MARK: Background — rounded square with diagonal gradient
let bg = CGRect(x: 0, y: 0, width: size, height: size)
ctx.saveGState()
ctx.addPath(rounded(bg, 224))
ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(0.36, 0.47, 1.0), rgb(0.51, 0.36, 0.98)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 120, y: size - 80),
                       end: CGPoint(x: size - 80, y: 120), options: [])
ctx.restoreGState()

// MARK: Back card (the duplicate / "copy")
let back = CGRect(x: 360, y: 300, width: 410, height: 470)
ctx.addPath(rounded(back, 78))
ctx.setFillColor(rgb(1, 1, 1, 0.45))
ctx.fillPath()

// MARK: Front card + cat ears (one white silhouette)
let front = CGRect(x: 268, y: 250, width: 410, height: 470)
let cat = CGMutablePath()
cat.addPath(rounded(front, 78))
let topY = front.maxY
// left ear
cat.move(to: CGPoint(x: 322, y: topY - 18))
cat.addLine(to: CGPoint(x: 388, y: topY + 96))
cat.addLine(to: CGPoint(x: 452, y: topY - 18))
cat.closeSubpath()
// right ear
cat.move(to: CGPoint(x: 494, y: topY - 18))
cat.addLine(to: CGPoint(x: 558, y: topY + 96))
cat.addLine(to: CGPoint(x: 624, y: topY - 18))
cat.closeSubpath()
ctx.addPath(cat)
ctx.setFillColor(rgb(1, 1, 1))
ctx.fillPath()

// inner ears (soft coral)
let inner = CGMutablePath()
inner.move(to: CGPoint(x: 360, y: topY + 2))
inner.addLine(to: CGPoint(x: 388, y: topY + 64))
inner.addLine(to: CGPoint(x: 416, y: topY + 2))
inner.closeSubpath()
inner.move(to: CGPoint(x: 530, y: topY + 2))
inner.addLine(to: CGPoint(x: 558, y: topY + 64))
inner.addLine(to: CGPoint(x: 586, y: topY + 2))
inner.closeSubpath()
ctx.addPath(inner)
ctx.setFillColor(rgb(0.99, 0.64, 0.71))
ctx.fillPath()

// MARK: Face — eyes, nose, whiskers (gradient-tinted)
let ink = rgb(0.42, 0.43, 0.95)
let cx = front.midX  // 473

// eyes
ctx.setFillColor(ink)
let eyeR: CGFloat = 33
ctx.fillEllipse(in: CGRect(x: cx - 95 - eyeR, y: 540 - eyeR, width: eyeR * 2, height: eyeR * 2))
ctx.fillEllipse(in: CGRect(x: cx + 95 - eyeR, y: 540 - eyeR, width: eyeR * 2, height: eyeR * 2))

// nose (small downward triangle)
let nose = CGMutablePath()
nose.move(to: CGPoint(x: cx - 26, y: 470))
nose.addLine(to: CGPoint(x: cx + 26, y: 470))
nose.addLine(to: CGPoint(x: cx, y: 430))
nose.closeSubpath()
ctx.addPath(nose)
ctx.setFillColor(ink)
ctx.fillPath()

// whiskers
ctx.setStrokeColor(ink)
ctx.setLineWidth(9)
ctx.setLineCap(.round)
func whisker(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
    ctx.move(to: CGPoint(x: x1, y: y1)); ctx.addLine(to: CGPoint(x: x2, y: y2)); ctx.strokePath()
}
whisker(cx - 70, 472, cx - 170, 492)
whisker(cx - 70, 450, cx - 172, 442)
whisker(cx + 70, 472, cx + 170, 492)
whisker(cx + 70, 450, cx + 172, 442)

NSGraphicsContext.restoreGraphicsState()
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
