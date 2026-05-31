import HealthKit

enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
    case heartRateTypeUnavailable

    var localizedDescription: String {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "Permission to access health data was denied"
        case .heartRateTypeUnavailable:
            return "Heart rate data type is not available"
        }
    }
}

final class HealthKitManager {
    private let healthStore = HKHealthStore()
    private var anchor: HKQueryAnchor?
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthKitError.notAvailable)
            return
        }

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false, HealthKitError.heartRateTypeUnavailable)
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [hrType]) { success, error in
            if !success {
                completion(false, error ?? HealthKitError.authorizationDenied)
            } else {
                completion(true, nil)
            }
        }
    }

    func startObservingHeartRate(onSamples: @escaping ([HKQuantitySample]) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let observer = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] (query: HKObserverQuery, completionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) in
            if let error = error {
                print("⚠️ Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            self?.fetchNewHeartRates { samples in
                onSamples(samples)
                completionHandler()
            }
        }

        observerQuery = observer
        healthStore.execute(observer)
        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { success, error in
            if success {
                print("✓ Background delivery enabled for heart rate")
            } else {
                print("⚠️ Failed to enable background delivery: \(error?.localizedDescription ?? "unknown")")
            }
        }

        // Initial fetch to deliver recent data immediately
        fetchNewHeartRates(onSamples)
    }

    private func fetchNewHeartRates(_ onSamples: @escaping ([HKQuantitySample]) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let query = HKAnchoredObjectQuery(type: hrType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) {
            [weak self] _, samplesOrNil, _, newAnchor, _ in
            self?.anchor = newAnchor
            let samples = (samplesOrNil as? [HKQuantitySample]) ?? []
            onSamples(samples)
        }
        query.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, _ in
            self?.anchor = newAnchor
            let samples = (samplesOrNil as? [HKQuantitySample]) ?? []
            onSamples(samples)
        }
        anchoredQuery = query
        healthStore.execute(query)
    }

    func stopObservingHeartRate() {
        if let observer = observerQuery {
            healthStore.stop(observer)
            observerQuery = nil
        }
        if let anchored = anchoredQuery {
            healthStore.stop(anchored)
            anchoredQuery = nil
        }
        print("✓ Stopped observing heart rate")
    }
}
