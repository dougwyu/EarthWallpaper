import Foundation

// We deliberately do NOT use CoreLocation's CLGeocoder. On Macs whose Apple
// account/region resolves to mainland China, CLGeocoder uses a restricted
// backend that cannot resolve international place names — it returns garbage
// coordinates inside China (e.g. "London" → Sichuan) or fails outright.
// Open-Meteo's geocoding API is free, needs no key, and resolves cities
// worldwide, returning latitude, longitude, country, and IANA timezone.

enum GeocoderError: LocalizedError {
    case notFound(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return "'\(name)' not found. Check the spelling, or add a country, e.g. 'Springfield, United States'."
        case .network(let msg):
            return "Could not reach the geocoding service: \(msg)"
        }
    }
}

struct GeocodeResult {
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    let country: String
}

func geocodeCity(_ query: String) async throws -> GeocodeResult {
    var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
    comps.queryItems = [
        URLQueryItem(name: "name", value: query),
        URLQueryItem(name: "count", value: "1"),
        URLQueryItem(name: "language", value: "en"),
        URLQueryItem(name: "format", value: "json")
    ]
    guard let url = comps.url else { throw GeocoderError.notFound(query) }

    let data: Data
    do {
        (data, _) = try await URLSession.shared.data(from: url)
    } catch {
        throw GeocoderError.network(error.localizedDescription)
    }

    struct Response: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let timezone: String?
            let country: String?
        }
        let results: [Result]?
    }

    guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
          let first = decoded.results?.first else {
        throw GeocoderError.notFound(query)
    }

    return GeocodeResult(
        name: first.name,
        latitude: first.latitude,
        longitude: first.longitude,
        timezone: first.timezone ?? TimeZone.current.identifier,
        country: first.country ?? ""
    )
}
