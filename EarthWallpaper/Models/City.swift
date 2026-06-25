import Foundation

struct City: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var timezone: String
    var country: String?   // nil for cities added before this field existed

    init(id: UUID = UUID(), name: String, latitude: Double,
         longitude: Double, timezone: String, country: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.country = country
    }

    func currentTime(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: date)
    }
}
