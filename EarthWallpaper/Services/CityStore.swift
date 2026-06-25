import Foundation
import Combine

class CityStore: ObservableObject {
    @Published private(set) var cities: [City] = []
    private let key: String

    init(userDefaultsKey: String = "cities") {
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
        guard let data = try? JSONEncoder().encode(cities) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([City].self, from: data)
        else { return }
        cities = saved
    }
}
