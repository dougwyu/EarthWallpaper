import SwiftUI
import AppKit

@main
struct EarthWallpaperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appState.cityStore)
                .environmentObject(appState.updater)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState.cityStore)
                .environmentObject(appState.updater)
        }
    }

    // Colored, slightly-larger menu bar icon: green continents over a blue ocean.
    // A non-template image keeps its color (template images are forced monochrome).
    // The drawing handler is re-invoked per scale, so it stays crisp on Retina.
    private static let menuBarIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)   // a touch larger than the default ~16pt
        let image = NSImage(size: size, flipped: false) { rect in
            // Blue ocean disc, inset to sit inside the globe's rim.
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)).fill()
            // Continents + rim on top (the symbol's ocean is transparent). A
            // slightly cool sea-green nudges the overall icon a touch bluer.
            let land = NSColor(srgbRed: 0.24, green: 0.72, blue: 0.52, alpha: 1)
            let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [land]))
            NSImage(systemSymbolName: "globe.americas.fill", accessibilityDescription: "EarthWallpaper")?
                .withSymbolConfiguration(config)?
                .draw(in: rect)
            return true
        }
        image.isTemplate = false   // preserve color in the menu bar
        return image
    }()
}
