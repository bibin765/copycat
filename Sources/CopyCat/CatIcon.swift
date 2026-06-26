import AppKit

enum CatIcon {
    /// Monochrome cat-head glyph used as the menu bar template image.
    /// Drawn as a template so macOS tints it for light/dark menu bars.
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)

            // head (filled on its own so it unions cleanly with the ears)
            ctx.fillEllipse(in: CGRect(x: 3.6, y: 1.6, width: 10.8, height: 10.4))

            // ears
            let ears = CGMutablePath()
            ears.move(to: CGPoint(x: 4.4, y: 8.0))
            ears.addLine(to: CGPoint(x: 4.9, y: 16.8))
            ears.addLine(to: CGPoint(x: 9.0, y: 10.6))
            ears.closeSubpath()
            ears.move(to: CGPoint(x: 9.0, y: 10.6))
            ears.addLine(to: CGPoint(x: 13.1, y: 16.8))
            ears.addLine(to: CGPoint(x: 13.6, y: 8.0))
            ears.closeSubpath()
            ctx.addPath(ears)
            ctx.fillPath()

            // eyes (punched out so the menu bar shows through)
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: 6.45, y: 6.2, width: 1.7, height: 2.0))
            ctx.fillEllipse(in: CGRect(x: 9.85, y: 6.2, width: 1.7, height: 2.0))
            ctx.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        return image
    }
}
