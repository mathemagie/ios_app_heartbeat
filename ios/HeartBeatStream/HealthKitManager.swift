import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()
    private var anchor: HKQueryAnchor?

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false, nil)
            return
        }
        healthStore.requestAuthorization(toShare: [], read: [hrType], completion: completion)
    }

    func startObservingHeartRate(onSamples: @escaping ([HKQuantitySample]) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let observer = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] _, _, completionHandler, _ in
            self?.fetchNewHeartRates { samples in
                onSamples(samples)
                completionHandler()
            }
        }

        healthStore.execute(observer)
        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in }

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
        healthStore.execute(query)
    }
}


