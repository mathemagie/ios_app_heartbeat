import HealthKit

final class HeartRateStreamer {
    private let hk: HealthKitManager
    var onHeartRateUpdate: ((Int, Date, String) -> Void)? // Callback for UI updates

    init(healthKit: HealthKitManager) {
        self.hk = healthKit
    }

    func start(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        hk.requestAuthorization { [weak self] granted, error in
            guard let self = self else {
                completion(false, nil)
                return
            }

            if !granted {
                completion(false, error)
                return
            }

            self.hk.startObservingHeartRate { [weak self] samples in
                guard let self = self else { return }
                for s in samples {
                    let bpm = s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    let bpmInt = Int(round(bpm))
                    // Send heart rate to UI instead of Firebase
                    self.onHeartRateUpdate?(bpmInt, s.endDate, s.sourceRevision.source.name)
                }
            }
            completion(true, nil)
        }
    }

    func stop() {
        hk.stopObservingHeartRate()
    }
}
