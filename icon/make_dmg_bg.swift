import AppKit

let W: CGFloat = 600, H: CGFloat = 400
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

// soft gradient background
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(0.96, 0.97, 1.0), rgb(0.93, 0.93, 0.98)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// arrow from the app (left, ~x150) toward Applications (right, ~x450), at icon row y≈200 from top
let y = H - 200            // Finder places icons ~200px down; mirror that here
ctx.setStrokeColor(rgb(0.55, 0.50, 0.95, 0.9))
ctx.setLineWidth(10)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 250, y: y))
ctx.addLine(to: CGPoint(x: 350, y: y))
ctx.strokePath()
// arrowhead
ctx.setFillColor(rgb(0.55, 0.50, 0.95, 0.9))
let head = CGMutablePath()
head.move(to: CGPoint(x: 372, y: y))
head.addLine(to: CGPoint(x: 344, y: y + 16))
head.addLine(to: CGPoint(x: 344, y: y - 16))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()

// caption
let text = "Drag CopyCat onto Applications to install"
let style = NSMutableParagraphStyle(); style.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(srgbRed: 0.40, green: 0.40, blue: 0.55, alpha: 1),
    .paragraphStyle: style,
]
NSString(string: text).draw(in: CGRect(x: 0, y: 48, width: W, height: 24), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
