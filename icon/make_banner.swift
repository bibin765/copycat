import AppKit

// Generates the Gumroad cover (1280x720) and square thumbnail (1024x1024)
// from the app icon, written to the project root.

let icon = NSImage(contentsOf: URL(fileURLWithPath: "icon/icon_1024.png"))!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func makeContext(_ w: Int, _ h: Int) -> (NSBitmapImageRep, CGContext) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    return (rep, NSGraphicsContext.current!.cgContext)
}

func gradient(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [rgb(0.31, 0.39, 0.96).cgColor, rgb(0.49, 0.32, 0.88).cgColor] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])
}

func text(_ s: String, _ rect: CGRect, size: CGFloat, weight: NSFont.Weight,
          color: NSColor, align: NSTextAlignment, shadow: Bool = true) {
    let style = NSMutableParagraphStyle(); style.alignment = align; style.lineSpacing = 2
    var attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    if shadow {
        let sh = NSShadow(); sh.shadowColor = rgb(0, 0, 0, 0.25)
        sh.shadowBlurRadius = 8; sh.shadowOffset = NSSize(width: 0, height: -2)
        attrs[.shadow] = sh
    }
    NSString(string: s).draw(in: rect, withAttributes: attrs)
}

func drawIcon(in rect: CGRect, ctx: CGContext) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30,
                  color: rgb(0, 0, 0, 0.35).cgColor)
    icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGState()
}

func write(_ rep: NSBitmapImageRep, _ path: String) {
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// ---------- COVER 1280x720 ----------
do {
    let W: CGFloat = 1280, H: CGFloat = 720
    let (rep, ctx) = makeContext(Int(W), Int(H))
    gradient(ctx, W, H)
    drawIcon(in: CGRect(x: 110, y: 170, width: 380, height: 380), ctx: ctx)

    let xT: CGFloat = 560, wT: CGFloat = 660
    text("CopyCat", CGRect(x: xT, y: 392, width: wT, height: 120),
         size: 92, weight: .bold, color: .white, align: .left)
    text("A smart clipboard shelf\nfor your menu bar.", CGRect(x: xT, y: 280, width: wT, height: 110),
         size: 32, weight: .medium, color: rgb(1, 1, 1, 0.92), align: .left)
    text("Stash · drag · paste — from anywhere on your Mac.",
         CGRect(x: xT, y: 232, width: wT, height: 36),
         size: 21, weight: .regular, color: rgb(1, 1, 1, 0.75), align: .left)

    // little "for macOS" pill
    let pill = CGRect(x: xT, y: 168, width: 150, height: 40)
    let path = CGPath(roundedRect: pill, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.addPath(path); ctx.setFillColor(rgb(1, 1, 1, 0.18).cgColor); ctx.fillPath()
    text("for macOS 14+", CGRect(x: pill.minX, y: pill.minY + 9, width: pill.width, height: 24),
         size: 16, weight: .semibold, color: .white, align: .center, shadow: false)

    write(rep, "assets/banner.png")
}

// ---------- THUMBNAIL 1024x1024 ----------
do {
    let S: CGFloat = 1024
    let (rep, ctx) = makeContext(Int(S), Int(S))
    gradient(ctx, S, S)
    drawIcon(in: CGRect(x: (S - 600) / 2, y: 320, width: 600, height: 600), ctx: ctx)
    text("CopyCat", CGRect(x: 0, y: 168, width: S, height: 110),
         size: 88, weight: .bold, color: .white, align: .center)
    text("Clipboard shelf for your menu bar",
         CGRect(x: 0, y: 110, width: S, height: 44),
         size: 30, weight: .medium, color: rgb(1, 1, 1, 0.8), align: .center)
    write(rep, "assets/social.png")
}
