import Foundation
import Combine

@MainActor
class CityStore: ObservableObject {
    @Published private(set) var cities: [City] = []
    private let key: String

    init(userDefaultsKey: String = "com.earthwallpaper.cities") {
        self.key = userDefaultsKey
        load()
    }

    func add(_ city: City) {
        cities.append(city)
        save()
    }

    func remove(at offsets: IndexSet) {
        cities.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(cities)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            assertionFailure("CityStore: encode failed — \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([City].self, from: data)
        else { return }
        cities = saved
    }
}
