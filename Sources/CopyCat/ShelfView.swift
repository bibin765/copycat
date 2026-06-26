import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    /// Posted by the panel UI to ask the app delegate to hide the shelf.
    static let copyCatHidePanel = Notification.Name("copyCatHidePanel")
}

/// A transparent AppKit view that drags its window when grabbed. Placed behind
/// the header so only the header moves the panel (the body is free for drops).
private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragHandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragHandleView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct ShelfView: View {
    @EnvironmentObject private var store: ShelfStore
    @EnvironmentObject private var updater: UpdaterManager
    @State private var isTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340, height: 420)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: CatIcon.menuBarImage())
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(.tint)
            Text("CopyCat")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                store.isWatching.toggle()
            } label: {
                Image(systemName: store.isWatching ? "dot.radiowaves.left.and.right" : "wifi.slash")
                    .foregroundStyle(store.isWatching ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .help(store.isWatching
                  ? "Auto-capture is ON — everything you copy is added (password managers excluded). Click to pause."
                  : "Auto-capture is OFF — copies aren't added automatically. Click to enable.")

            Button {
                store.copyAllInOrder()
            } label: {
                Image(systemName: "list.number")
            }
            .buttonStyle(.plain)
            .disabled(!store.hasTextItems)
            .help("Copy all in order — put every text item on the clipboard, #1 first")

            Button {
                store.captureClipboard()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Add clipboard — stash whatever you last copied onto the shelf")

            Button {
                store.clearAll()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(store.items.isEmpty)
            .help("Clear shelf — remove all items")

            Button {
                NotificationCenter.default.post(name: .copyCatHidePanel, object: nil)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Hide shelf — reopen anytime with ⌥⌘V")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WindowDragHandle())   // drag the panel around by its header
    }

    // MARK: - Content

    private var content: some View {
        ZStack {
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        // Oldest-first so numbers read 1, 2, 3… top to bottom.
                        ForEach(Array(store.items.reversed().enumerated()), id: \.element.id) { index, item in
                            ItemCardView(item: item, orderNumber: index + 1)
                        }
                    }
                    .padding(14)
                }
            }

            if isTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: ShelfView.acceptedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop anything here")
                .font(.system(size: 13, weight: .medium))
            Text("Text, images, links or files.\nDrag them back out whenever you need.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Toggle anytime with ⌥⌘V")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(store.items.isEmpty ? "Empty shelf"
                                     : "^[\(store.items.count) item](inflect: true)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if !store.items.isEmpty {
                Text("· press 1–9 to paste")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .help("Press a number key to paste that item into the app you came from")
            }
            Spacer()
            menu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var menu: some View {
        Menu {
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
            Divider()
            Button("Quit CopyCat") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 12))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More options")
    }

    // MARK: - Drop handling

    static let acceptedTypes: [UTType] = [.fileURL, .image, .url, .plainText, .utf8PlainText]

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    DispatchQueue.main.async { store.addFile(at: url) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                let suggested = provider.suggestedName ?? "Image"
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async { store.addImage(image, suggestedName: suggested) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { store.addText(url.absoluteString) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                handled = true
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    guard let string else { return }
                    DispatchQueue.main.async { store.addText(string) }
                }
            }
        }
        return handled
    }
}
