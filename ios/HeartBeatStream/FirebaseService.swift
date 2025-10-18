import Foundation
import FirebaseAuth
import FirebaseDatabase

final class FirebaseService {
    private let db = Database.database().reference()
    private let shareId: String

    init(shareId: String) { self.shareId = shareId }

    private func timestampKey(for date: Date) -> String {
        String(Int(date.timeIntervalSince1970 * 1000))
    }

    func writeHeartRate(bpm: Int, start: Date, end: Date, source: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ts = timestampKey(for: end)
        let sample: [String: Any] = [
            "bpm": bpm,
            "start": ISO8601DateFormatter().string(from: start),
            "end": ISO8601DateFormatter().string(from: end),
            "source": source
        ]
        db.child("users/\(uid)/heartRate/\(ts)").setValue(sample)
        db.child("publicStreams/\(shareId)/latest").setValue(sample)
        db.child("publicStreams/\(shareId)/heartRate/\(ts)").setValue(sample)
    }
}


