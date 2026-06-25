import Foundation

@MainActor
class AppState: ObservableObject {
    let cityStore = CityStore()
    lazy var updater: WallpaperUpdater = WallpaperUpdater(cityStore: cityStore)
}
