import AppKit

/// Sits on top of the menu bar status button. Turns the icon into both a click
/// target (toggle the panel) and a drop target (stash content onto the shelf
/// without opening the panel at all).
final class StatusDropView: NSView {
    var onClick: (() -> Void)?
    var onDrop: ((NSPasteboard) -> Void)?

    private static let acceptedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .png, .tiff, .string, .URL]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.acceptedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.acceptedTypes)
    }

    // MARK: - Click

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    // MARK: - Drag destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        highlight(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlight(false)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        highlight(false)
    }

    private func highlight(_ on: Bool) {
        (superview as? NSButton)?.highlight(on)
    }
}
