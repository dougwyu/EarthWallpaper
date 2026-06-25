import Foundation
import Combine

class WallpaperUpdater: ObservableObject {
    @Published var isUpdating = false
    @Published var lastError: String?
    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "com.earthwallpaper.intervalMinutes")
            reschedule()
        }
    }

    private var timer: Timer?
    private var currentCities: [City] = []
    private var cancellables = Set<AnyCancellable>()

    init(cityStore: CityStore) {
        let saved = UserDefaults.standard.integer(forKey: "com.earthwallpaper.intervalMinutes")
        self.intervalMinutes = saved > 0 ? saved : 5

        cityStore.$cities
            .sink { [weak self] cities in self?.currentCities = cities }
            .store(in: &cancellables)

        reschedule()

        // Generate wallpaper once at startup after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performUpdate()
        }
    }

    func updateNow() {
        performUpdate()
    }

    private func performUpdate() {
        let cities = currentCities
        isUpdating = true
        lastError = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try XPlanetRunner.run(cities: cities)
                DispatchQueue.main.async { self?.isUpdating = false }
            } catch {
                DispatchQueue.main.async {
                    self?.isUpdating = false
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    private func reschedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in self?.performUpdate() }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
