import HealthKit

final class HeartRateStreamer {
    private let hk: HealthKitManager
    private let firebase: FirebaseService

    init(healthKit: HealthKitManager, firebase: FirebaseService) {
        self.hk = healthKit
        self.firebase = firebase
    }

    func start() {
        hk.requestAuthorization { [weak self] granted, _ in
            guard granted else { return }
            self?.hk.startObservingHeartRate { [weak self] samples in
                guard let self = self else { return }
                for s in samples {
                    let bpm = s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    self.firebase.writeHeartRate(
                        bpm: Int(round(bpm)),
                        start: s.startDate,
                        end: s.endDate,
                        source: s.sourceRevision.source.name
                    )
                }
            }
        }
    }
}


