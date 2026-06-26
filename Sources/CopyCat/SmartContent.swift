import AppKit

/// Lightweight detection that gives shelf items a "smart" presentation:
/// color swatches, code formatting, etc.
enum SmartContent {

    /// Parses a color literal (`#FF6A88`, `#f60`, `rgb(255,106,136)`).
    static func color(from raw: String) -> NSColor? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return hexColor(s) ?? rgbColor(s)
    }

    private static func hexColor(_ s: String) -> NSColor? {
        var hex = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard !hex.isEmpty, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }   // #f60 -> #ff6600
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        if hex.count == 8 {
            r = CGFloat((value >> 24) & 0xFF) / 255; g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255;  a = CGFloat(value & 0xFF) / 255
        } else {
            r = CGFloat((value >> 16) & 0xFF) / 255; g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255;          a = 1
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    private static func rgbColor(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        guard lower.hasPrefix("rgb"),
              let open = lower.firstIndex(of: "("), let close = lower.firstIndex(of: ")") else { return nil }
        let parts = lower[lower.index(after: open)..<close]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        func num(_ x: String) -> CGFloat? { Double(x).map { CGFloat($0) } }
        guard let r = num(parts[0]), let g = num(parts[1]), let b = num(parts[2]) else { return nil }
        let aRaw = parts.count == 4 ? (num(parts[3]) ?? 1) : 1
        return NSColor(srgbRed: min(r, 255) / 255, green: min(g, 255) / 255,
                       blue: min(b, 255) / 255, alpha: aRaw <= 1 ? aRaw : aRaw / 255)
    }

    /// Heuristically decides whether a snippet looks like source code.
    static func isCode(_ text: String) -> Bool {
        let tokens = ["func ", "const ", "let ", "var ", "def ", "class ", "import ",
                      "function", "=>", "</", "/>", "#include", "public ", "private ", "return "]
        if tokens.contains(where: text.contains) { return true }
        let symbols = CharacterSet(charactersIn: "{};=>")
        let hasSymbols = text.unicodeScalars.contains(where: symbols.contains)
        return text.contains("\n") && hasSymbols
    }
}

extension NSColor {
    /// Black or white, whichever reads better on top of this color.
    var readableForeground: NSColor {
        guard let c = usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return luminance > 0.6 ? .black : .white
    }
}
