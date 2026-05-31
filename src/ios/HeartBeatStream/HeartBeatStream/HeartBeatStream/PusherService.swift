import Foundation

/// Upload connection states, surfaced to the UI.
enum UploadState: String {
    case idle
    case sending
    case ok
    case error
}

/// Sends heart-rate readings to the Vercel serverless API, which publishes them
/// to a public Pusher channel. No Pusher secret lives in the app — the server
/// holds it. Replaces the previous direct-to-Pusher (PusherSwift) integration.
final class PusherService {
    private let shareId: String
    private let session: URLSession

    /// Base URL of the deployed Vercel app, e.g. https://your-app.vercel.app
    /// Override via the `HEARTBEAT_API_BASE_URL` Info.plist key if present.
    private let baseURL: URL

    // Rate limiting: publish at most once every 2 seconds.
    private var lastPublishTime: Date?
    private let minimumPublishInterval: TimeInterval = 2.0

    var onConnectionStateChange: ((UploadState) -> Void)?

    init(shareId: String, session: URLSession = .shared) {
        self.shareId = shareId
        self.session = session

        let configured = Bundle.main.object(forInfoDictionaryKey: "HEARTBEAT_API_BASE_URL") as? String
        // Deployed Vercel app (override via HEARTBEAT_API_BASE_URL in Info.plist).
        let urlString = (configured?.isEmpty == false ? configured! : "https://project-56opg.vercel.app")
        self.baseURL = URL(string: urlString) ?? URL(string: "https://example.com")!
    }

    func connect() {
        onConnectionStateChange?(.idle)
        print("📡 Heart rate API base: \(baseURL.absoluteString)")
    }

    func disconnect() {
        onConnectionStateChange?(.idle)
    }

    func publishHeartRate(bpm: Int, timestamp: Date, source: String) {
        // Rate limiting.
        let now = Date()
        if let last = lastPublishTime, now.timeIntervalSince(last) < minimumPublishInterval {
            return
        }
        lastPublishTime = now

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "bpm": bpm,
            "timestamp": isoFormatter.string(from: timestamp),
            "source": source,
            "shareId": shareId
        ]

        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            onConnectionStateChange?(.error)
            return
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/heartbeat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        onConnectionStateChange?(.sending)
        let task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ Upload failed: \(error.localizedDescription)")
                self.onConnectionStateChange?(.error)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) {
                print("📤 Published heart rate: \(bpm) BPM")
                self.onConnectionStateChange?(.ok)
            } else {
                print("⚠️ Upload HTTP \(status)")
                self.onConnectionStateChange?(.error)
            }
        }
        task.resume()
    }
}
