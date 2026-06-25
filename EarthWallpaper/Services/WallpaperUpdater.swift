import Foundation
import Combine

@MainActor
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
        guard !isUpdating else { return }
        let cities = currentCities
        isUpdating = true
        lastError = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let imageURL = try XPlanetRunner.run(cities: cities)
                DispatchQueue.main.async {
                    DesktopOverlay.shared.show(imageURL: imageURL)
                    self?.isUpdating = false
                }
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
        let interval = TimeInterval(intervalMinutes * 60)

        // Align fires to interval boundaries relative to the top of the hour so
        // the rendered clock matches wall time. Without this, the timer fires at
        // an arbitrary phase (whenever the app launched / the interval changed),
        // so the displayed minute can lag the real minute by almost a full
        // period. The +0.3s offset lets Date() tick into the new minute before
        // we read it; the image then appears ~1-2s after the boundary (xplanet
        // render time), keeping the label current for the rest of the period.
        let now = Date()
        let secondsIntoPeriod = now.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: interval)
        let firstFire = now.addingTimeInterval(interval - secondsIntoPeriod + 0.3)

        let t = Timer(fire: firstFire, interval: interval, repeats: true) { [weak self] _ in
            self?.performUpdate()
        }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
