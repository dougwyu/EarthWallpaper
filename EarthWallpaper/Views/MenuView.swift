import SwiftUI

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
                        Text(city.currentTime())
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
            }

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

            SettingsLink {
                Text("Settings…")
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            Divider().padding(.vertical, 4)

            Button("Quit EarthWallpaper") { NSApplication.shared.terminate(nil) }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .frame(minWidth: 240)
        .onReceive(clockTimer) { tick = $0 }
    }
}
