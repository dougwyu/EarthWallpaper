import AppKit

// Displays the rendered Earth map in borderless windows pinned at the desktop
// layer — one per screen — instead of setting the macOS desktop picture.
//
// Why not the real wallpaper: on macOS 26 the wallpaper system only reliably
// repaints when handed a brand-new file path, so frequent updates either freeze
// or pile thousands of entries into Settings → "Your Photos". A desktop-level
// window sidesteps all of that: it repaints instantly, needs no permission, and
// leaves no trace in Settings. It sits just below the desktop icons (above the
// system wallpaper) and is revealed by the Show Desktop / Mission Control key,
// exactly like a wallpaper. It ignores mouse events so clicks reach the icons.
@MainActor
final class DesktopOverlay {
    static let shared = DesktopOverlay()

    private var windows: [NSWindow] = []
    private var currentImage: NSImage?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Show (or refresh) the overlay with a freshly composited image. Taking a
    /// CGImage directly avoids an 8 MB PNG encode + decode round-trip per tick.
    func show(cgImage: CGImage) {
        let image = NSImage(cgImage: cgImage, size: .zero)   // .zero → use pixel size
        currentImage = image
        rebuildWindows()
        apply(image)
    }

    @objc private func screensChanged() {
        rebuildWindows(force: true)
        if let image = currentImage { apply(image) }
    }

    private func apply(_ image: NSImage) {
        for window in windows {
            (window.contentView as? NSImageView)?.image = image
        }
    }

    private func rebuildWindows(force: Bool = false) {
        let screens = NSScreen.screens
        if !force && windows.count == screens.count {
            // Keep existing windows; just make sure they still cover their screen.
            for (window, screen) in zip(windows, screens) {
                window.setFrame(screen.frame, display: true)
            }
            return
        }
        for window in windows { window.orderOut(nil) }
        windows = screens.map(makeWindow(for:))
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        // Just below the desktop icons → behaves like a wallpaper (icons on top,
        // app windows on top, system wallpaper hidden behind it).
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
        imageView.imageScaling = .scaleAxesIndependently   // fill the screen
        imageView.image = currentImage
        imageView.autoresizingMask = [.width, .height]
        window.contentView = imageView

        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
        return window
    }
}
