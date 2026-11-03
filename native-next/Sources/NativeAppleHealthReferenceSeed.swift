#if DEBUG
import SwiftUI
import HealthKit

/// A CI-only entry point: all HealthKit writes are compiled out on real devices.
struct NativeAppleHealthReferenceSeed: View {
    @State private var status = "Preparazione"
    var body: some View {
        VStack(spacing: NativeDesign.Space.large) {
            Text("Riferimento Apple Salute").font(.headline)
            Text(status).accessibilityIdentifier("apple-health-reference-seed-status")
        }.task { await prepare() }
    }
    @MainActor private func prepare() async {
        #if targetEnvironment(simulator)
        do {
            let health = HKHealthStore()
            let weight = HKObjectType.quantityType(forIdentifier: .bodyMass)!
            let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
            let types: Set<HKSampleType> = [weight, energy]
            status = "Autorizzazione sul simulatore"
            try await health.requestAuthorization(toShare: types, read: [])
            guard types.allSatisfy({ health.authorizationStatus(for: $0) == .sharingAuthorized }) else {
                throw Message(text: "Scrittura di riferimento non autorizzata sul simulatore")
            }
            let end = Date().addingTimeInterval(-600)
            var samples: [HKQuantitySample] = []
            for offset in -6...0 {
                let date = CivilDate.calendar.date(byAdding: .day, value: offset, to: end)!
                let day = CivilDate.day(date)
                for (type, quantity, key) in [
                    (weight, HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 80 + Double(offset) * 0.05), "weight"),
                    (energy, HKQuantity(unit: .kilocalorie(), doubleValue: 2200 + Double((offset + 6) % 3) * 100), "energy")
                ] {
                    samples.append(HKQuantitySample(type: type, quantity: quantity, start: date, end: date,
                        metadata: [HKMetadataKeySyncIdentifier: "lifeos-reference78-\(key)-\(day)", HKMetadataKeySyncVersion: 1]))
                }
            }
            try await health.save(samples)
            status = "Dati pronti"
        } catch { status = error.localizedDescription }
        #else
        status = "Disponibile solo sul simulatore"
        #endif
    }
}
#endif
