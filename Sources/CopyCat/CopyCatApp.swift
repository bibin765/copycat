import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices

@main
struct CopyCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app lives entirely in the menu bar; this scene stays empty.
        Settings { EmptyView() }
    }
}

/// Owns the menu bar status item, the floating shelf panel, and the global hotkey.
///
/// A floating `NSPanel` (rather than an `NSPopover`) is what makes this usable as
/// a drag shelf: it stays open when you click elsewhere, floats above other apps,
/// and can be moved around — so you can drag items out into any window or Finder.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ShelfStore()
    let updater = UpdaterManager()

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var hotKey: HotKeyManager?
    private var keyMonitor: Any?
    /// The app that was frontmost when the panel opened — where quick-paste sends.
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)
        setupPanel()
        setupStatusItem()

        // ⌥⌘V toggles the panel from anywhere.
        hotKey = HotKeyManager(keyCode: HotKeyManager.keyV,
                               modifiers: HotKeyManager.optionCommand) { [weak self] in
            self?.togglePanel()
        }

        // The header's ✕ button asks us to hide the panel.
        NotificationCenter.default.addObserver(forName: .copyCatHidePanel,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.panel.orderOut(nil)
        }

        installQuickPasteMonitor()

        // Screenshot mode: open the panel on launch and print its window id so a
        // capture script can grab it. Env-gated — no effect in normal use.
        if ProcessInfo.processInfo.environment["COPYCAT_SCREENSHOT"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                self.positionPanel()
                self.panel.makeKeyAndOrderFront(nil)
                print("COPYCAT_WINDOW=\(self.panel.windowNumber)")
                fflush(stdout)
            }
        }
    }

    // MARK: - Quick paste (press 1–9)

    private func installQuickPasteMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }

            if event.keyCode == 53 {            // Esc closes the panel
                self.panel.orderOut(nil)
                return nil
            }
            // Plain digit 1–9 → paste that numbered item.
            let mods = event.modifierFlags.intersection([.command, .option, .control])
            guard mods.isEmpty,
                  let chars = event.charactersIgnoringModifiers,
                  let n = Int(chars), (1...9).contains(n) else {
                return event
            }
            self.quickPaste(number: n)
            return nil
        }
    }

    private func quickPaste(number: Int) {
        let count = store.items.count
        guard number <= count else { return }
        // #1 is the oldest item; store.items is newest-first.
        let item = store.items[count - number]
        store.copyToPasteboard(item)
        panel.orderOut(nil)

        previousApp?.activate()
        // Let the target app come forward, then send ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.sendPaste()
        }
    }

    private func sendPaste() {
        guard ensureAccessibilityTrust() else { return } // item is on the clipboard for manual ⌘V
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // 'V'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Auto-paste needs Accessibility permission. Prompt once; until granted we
    /// just leave the item on the clipboard so ⌘V works manually.
    private func ensureAccessibilityTrust() -> Bool {
        if AXIsProcessTrusted() { return true }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        return false
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // Move the panel only via its header drag handle, so dragging items in/out
        // of the body never gets hijacked into a window move.
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.level = .floating                     // stays above normal windows
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentViewController = NSHostingController(
            rootView: ShelfView()
                .environmentObject(store)
                .environmentObject(updater))
        self.panel = panel
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = CatIcon.menuBarImage()
        button.toolTip = "CopyCat — click or ⌥⌘V to open · drop here to stash"

        // Overlay a view that handles both clicks (toggle) and drops (stash to
        // shelf without opening the panel).
        let dropView = StatusDropView(frame: button.bounds)
        dropView.autoresizingMask = [.width, .height]
        dropView.onClick = { [weak self] in self?.togglePanel() }
        dropView.onDrop = { [weak self] pasteboard in
            self?.store.capture(from: pasteboard)
        }
        button.addSubview(dropView)
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // Remember where we came from so quick-paste can return there.
            let me = NSRunningApplication.current
            if let front = NSWorkspace.shared.frontmostApplication, front != me {
                previousApp = front
            }
            positionPanel()
            // A non-activating panel can be key without stealing focus from the
            // front app, so dragging out to other apps keeps working.
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Drops the panel just below the menu bar icon, clamped to the screen.
    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = NSPoint(x: buttonRect.midX - panel.frame.width / 2,
                             y: buttonRect.minY - 6)
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(visible.minX + 8, origin.x), visible.maxX - panel.frame.width - 8)
        }
        panel.setFrameTopLeftPoint(origin)
    }
}
