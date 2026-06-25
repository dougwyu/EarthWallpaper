import Foundation

struct City: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var timezone: String

    init(id: UUID = UUID(), name: String, latitude: Double,
         longitude: Double, timezone: String) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: Date())
    }
}
