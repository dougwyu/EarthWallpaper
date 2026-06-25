import CoreLocation

enum GeocoderError: LocalizedError {
    case notFound(String)
    case noTimezone(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return "City '\(name)' not found. Try a different spelling or add the country (e.g. 'Valencia, Spain')."
        case .noTimezone(let name):
            return "Found '\(name)' but could not determine its timezone."
        }
    }
}

func geocodeCity(_ name: String) async throws -> (latitude: Double, longitude: Double, timezone: String) {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.geocodeAddressString(name)
    guard let placemark = placemarks.first, let location = placemark.location else {
        throw GeocoderError.notFound(name)
    }
    guard let tz = placemark.timeZone else {
        throw GeocoderError.noTimezone(name)
    }
    return (location.coordinate.latitude, location.coordinate.longitude, tz.identifier)
}
