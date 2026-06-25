import SwiftUI

@main
struct EarthWallpaperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Earth", systemImage: "globe.americas.fill") {
            MenuView()
                .environmentObject(appState.cityStore)
                .environmentObject(appState.updater)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState.cityStore)
                .environmentObject(appState.updater)
        }
    }
}
