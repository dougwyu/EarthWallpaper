import SwiftUI
import AppKit

// Bring the Settings window to the foreground. Because the app is an accessory
// (LSUIElement = true), opening Settings does NOT activate the app, so the
// window appears behind other apps' windows. We must activate explicitly and
// order the window front. Called twice — once now, once after a short delay —
// because the window may not exist yet on the first call.
func bringSettingsWindowToFront() {
    func front() {
        NSApp.activate(ignoringOtherApps: true)
        let settings = NSApp.windows.first {
            $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
        } ?? NSApp.windows.first {
            $0.isVisible && $0.canBecomeMain && $0.styleMask.contains(.titled)
        }
        settings?.makeKeyAndOrderFront(nil)
        settings?.orderFrontRegardless()
    }
    DispatchQueue.main.async { front() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { front() }
}

@available(macOS 14.0, *)
private struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button("Settings…") {
            openSettings()
            bringSettingsWindowToFront()
        }
    }
}

struct MenuView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var updater: WallpaperUpdater
    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var tick = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cityStore.cities.isEmpty {
                Text("No cities — open Settings to add some.")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(cityStore.cities) { city in
                    HStack {
                        Text(city.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(city.currentTime(for: tick))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
            }

            let moon = MoonPhase(date: tick)
            HStack {
                Text("\(moon.emoji) Moon")
                    .fontWeight(.medium)
                Spacer()
                Text("\(moon.phaseName) · \(Int((moon.illuminatedFraction * 100).rounded()))%")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider().padding(.vertical, 4)

            if let error = updater.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            HStack {
                Button(updater.isUpdating ? "Updating…" : "Update Now") {
                    updater.updateNow()
                }
                .disabled(updater.isUpdating)
                if updater.isUpdating {
                    ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)

            Group {
                if #available(macOS 14.0, *) {
                    SettingsButton()
                } else {
                    Button("Settings…") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        bringSettingsWindowToFront()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            Divider().padding(.vertical, 4)

            Button("Quit EarthWallpaper") { NSApplication.shared.terminate(nil) }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .frame(minWidth: 240)
        // The menu's content view only receives timer ticks while it is open, and
        // SwiftUI keeps its `tick` state across open/close — so without this the
        // dropdown shows whatever time it held when first built. Refresh on every
        // appearance, and keep ticking each second while the menu stays open.
        .onAppear { tick = Date() }
        .onReceive(clockTimer) { tick = $0 }
    }
}
