#if DEBUG
import SwiftUI
import HealthKit

/// A CI-only entry point: all HealthKit writes are compiled out on real devices.
struct NativeAppleHealthReferenceSeed: View {
    @State private var status = "Preparazione"
    @State private var diagnostics = ""
    var body: some View {
        VStack(spacing: NativeDesign.Space.large) {
            Text("Riferimento Apple Salute").font(.headline)
            Text(status).accessibilityIdentifier("apple-health-reference-seed-status")
            Text(diagnostics).font(.caption2).accessibilityIdentifier("apple-health-reference-seed-diagnostics")
        }.task { await prepare() }
    }
    @MainActor private func prepare() async {
        #if targetEnvironment(simulator)
        let health = HKHealthStore()
        let weight = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        let types: Set<HKSampleType> = [weight, energy]
        var phase = "request-authorization"
        func reportAuthorization(_ stage: String) {
            for type in [weight, energy] {
                let value: String
                switch health.authorizationStatus(for: type) {
                case .notDetermined: value = "not-determined"
                case .sharingDenied: value = "sharing-denied"
                case .sharingAuthorized: value = "sharing-authorized"
                @unknown default: value = "unknown"
                }
                let entry = "HEALTH_REFERENCE_AUTH stage=\(stage) type=\(type.identifier) status=\(value)"
                diagnostics += entry + "\n"
                print(entry)
            }
        }
        do {
            status = "Autorizzazione sul simulatore"
            reportAuthorization("before-request")
            try await health.requestAuthorization(toShare: types, read: [])
            reportAuthorization("after-request")
            phase = "check-authorization"
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
            phase = "save-synthetic-samples"
            try await health.save(samples)
            diagnostics += "HEALTH_REFERENCE_SAVE result=success\n"
            print("HEALTH_REFERENCE_SAVE result=success")
            status = "Dati pronti"
        } catch {
            let failure = error as NSError
            reportAuthorization("failure")
            let entry = "HEALTH_REFERENCE_ERROR phase=\(phase) domain=\(failure.domain) code=\(failure.code)"
            diagnostics += entry
            print(entry)
            status = error.localizedDescription
        }
        #else
        status = "Disponibile solo sul simulatore"
        #endif
    }
}
#endif
