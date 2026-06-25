import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var updater: WallpaperUpdater

    @State private var cityInput = ""
    @State private var isGeocoding = false
    @State private var geocodeError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            GroupBox("Add City") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("e.g. Tokyo, London, New York", text: $cityInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addCity() }
                        Button("Add") { addCity() }
                            .disabled(cityInput.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                        if isGeocoding {
                            ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                        }
                    }
                    if let error = geocodeError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(4)
            }

            GroupBox("Cities") {
                if cityStore.cities.isEmpty {
                    Text("No cities added yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    List {
                        ForEach(cityStore.cities) { city in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name).fontWeight(.medium)
                                    Text(city.country ?? city.timezone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(city.currentTime())
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: cityStore.remove)
                    }
                    .frame(minHeight: 130)
                }
            }

            GroupBox("Update Interval") {
                Stepper(
                    "Every \(updater.intervalMinutes) minute\(updater.intervalMinutes == 1 ? "" : "s")",
                    value: $updater.intervalMinutes,
                    in: 1...60
                )
                .padding(4)
            }

            GroupBox {
                Text("Tip: assign a Function key to 'Show Desktop' in\nSystem Settings → Keyboard → Keyboard Shortcuts → Mission Control")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 360)
    }

    private func addCity() {
        let name = cityInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isGeocoding = true
        geocodeError = nil
        Task {
            do {
                let result = try await geocodeCity(name)
                let city = City(name: result.name, latitude: result.latitude,
                                longitude: result.longitude, timezone: result.timezone,
                                country: result.country.isEmpty ? nil : result.country)
                await MainActor.run {
                    cityStore.add(city)
                    cityInput = ""
                    isGeocoding = false
                }
            } catch {
                await MainActor.run {
                    geocodeError = error.localizedDescription
                    isGeocoding = false
                }
            }
        }
    }
}
