import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ItemCardView: View {
    let item: ShelfItem
    /// Position in copy order — 1 is the oldest item on the shelf.
    let orderNumber: Int
    @EnvironmentObject private var store: ShelfStore
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
                .frame(width: 92, height: 64)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
                .overlay(alignment: .bottomTrailing) { thumbnailAction }

            Text(item.name)
                .font(.system(size: 10))
                .lineLimit(2)
                .truncationMode(.middle)   // keep the file extension visible
                .multilineTextAlignment(.center)
                .frame(height: 26, alignment: .top)
                .foregroundStyle(.secondary)
                .help(item.name)            // full name on hover
        }
        .frame(width: 100)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hovering ? Color.primary.opacity(0.06) : .clear)
        )
        .overlay(alignment: .topLeading) { orderBadge }
        .overlay(alignment: .topTrailing) { deleteButton }
        .overlay {
            if copied {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                    )
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { copy() }
        .onDrag { dragProvider() }
        .help(cardTooltip)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 64)
                    .clipped()
            } else {
                icon("photo")
            }
        case .text:
            if let color = SmartContent.color(from: item.text ?? "") {
                colorSwatch(color)
            } else if SmartContent.isCode(item.text ?? "") {
                codePreview(item.text ?? "")
            } else {
                textPreview(item.text ?? "")
            }
        case .link:
            icon("link")
        case .file:
            icon(systemIcon(for: item.name))
        }
    }

    private func textPreview(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .lineLimit(4)
            .foregroundStyle(.primary)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func codePreview(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, design: .monospaced))
            .lineLimit(5)
            .foregroundStyle(.primary)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func colorSwatch(_ color: NSColor) -> some View {
        ZStack {
            Color(nsColor: color)
            Text(item.name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: color.readableForeground))
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(.secondary)
    }

    // MARK: - Per-type hover action (OCR for images, open for links)

    @ViewBuilder
    private var thumbnailAction: some View {
        if hovering {
            switch item.kind {
            case .image:
                actionChip("text.viewfinder", help: "Extract text (OCR)") {
                    store.extractText(from: item)
                }
            case .link:
                actionChip("arrow.up.right", help: "Open link") {
                    if let url = URL(string: item.text ?? "") { NSWorkspace.shared.open(url) }
                }
            default:
                EmptyView()
            }
        }
    }

    private func actionChip(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .padding(4)
        .help(help)
    }

    // MARK: - Order badge

    private var orderBadge: some View {
        Text("\(orderNumber)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(Color.accentColor))
            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .offset(x: -3, y: -3)
            .help("Item #\(orderNumber) — press \(orderNumber) to paste it")
    }

    /// Tooltip describing the item and what you can do with it.
    private var cardTooltip: String {
        let preview = item.text ?? item.name
        return "\(preview)\n\nClick to copy · Drag out to paste"
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            store.remove(item)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary, Color(nsColor: .windowBackgroundColor))
        }
        .buttonStyle(.plain)
        .opacity(hovering ? 1 : 0)
        .offset(x: 2, y: -2)
        .help("Remove this item")
    }

    // MARK: - Actions

    private func copy() {
        store.copyToPasteboard(item)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.2)) { copied = false }
        }
    }

    /// Builds the payload dragged OUT of the shelf to other apps / Finder.
    private func dragProvider() -> NSItemProvider {
        switch item.kind {
        case .text, .link:
            return NSItemProvider(object: (item.text ?? item.name) as NSString)
        case .image, .file:
            if let url = store.fileURL(for: item) {
                let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider()
                provider.suggestedName = exportName
                return provider
            }
            return NSItemProvider()
        }
    }

    /// A friendly filename for dragged-out files (the on-disk name is a UUID).
    private var exportName: String {
        if item.kind == .image && (item.name as NSString).pathExtension.isEmpty {
            return item.name + ".png"
        }
        return item.name
    }

    private func systemIcon(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "zip", "gz", "tar", "dmg": return "doc.zipper"
        case "mp4", "mov", "m4v", "avi": return "film"
        case "mp3", "wav", "aac", "m4a": return "music.note"
        case "txt", "md", "rtf": return "doc.text"
        case "swift", "js", "ts", "py", "rb", "go", "rs", "java", "c", "cpp", "json", "html", "css":
            return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}
