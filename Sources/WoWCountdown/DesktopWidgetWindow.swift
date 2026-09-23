import AppKit

/// Borderless panel just above the desktop icons: behind normal windows, on every Space.
final class DesktopWidgetWindow: NSPanel {
    init(contentView: NSView, size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Makes the whole widget a drag handle, including while the app is inactive.
final class DragHandleView: NSView {
    var onDragEnded: (() -> Void)?

    private var startMouse: NSPoint = .zero
    private var startOrigin: NSPoint = .zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        startMouse = NSEvent.mouseLocation
        startOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x, y: startOrigin.y + mouse.y - startMouse.y))
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded?()
    }
}
