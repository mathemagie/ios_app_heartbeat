import HealthKit
import PusherSwift

final class HeartRateStreamer {
    private let hk: HealthKitManager
    private let pusher: PusherService?
    var onHeartRateUpdate: ((Int, Date, String) -> Void)? // Callback for UI updates
    var onPusherConnectionChange: ((ConnectionState) -> Void)?

    init(healthKit: HealthKitManager, pusherService: PusherService? = nil) {
        self.hk = healthKit
        self.pusher = pusherService

        // Set up Pusher connection state callback
        pusherService?.onConnectionStateChange = { [weak self] state in
            self?.onPusherConnectionChange?(state)
        }
    }

    func start(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        // Connect to Pusher if available
        pusher?.connect()

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
                    let source = s.sourceRevision.source.name

                    // Send heart rate to UI
                    self.onHeartRateUpdate?(bpmInt, s.endDate, source)

                    // Send heart rate to Pusher if available
                    self.pusher?.publishHeartRate(bpm: bpmInt, timestamp: s.endDate, source: source)
                }
            }
            completion(true, nil)
        }
    }

    func stop() {
        hk.stopObservingHeartRate()
        pusher?.disconnect()
    }
}
