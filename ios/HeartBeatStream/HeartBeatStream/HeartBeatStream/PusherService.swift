import Foundation
import PusherSwift

final class PusherService {
    private var pusher: Pusher!
    private var channel: PusherChannel?
    private let shareId: String

    // TODO: Replace with your actual Pusher credentials
    private let pusherKey = "3b88050d4007e937f6d7"
    private let pusherCluster = "eu" // e.g., "us2", "eu", "ap1"
    private let pusherSecret = "b23e8785f7e108dfd7ba" // Get this from Pusher dashboard

    // Rate limiting
    private var lastPublishTime: Date?
    private let minimumPublishInterval: TimeInterval = 2.0 // Publish at most once every 2 seconds

    var onConnectionStateChange: ((ConnectionState) -> Void)?

    init(shareId: String) {
        self.shareId = shareId
        setupPusher()
    }

    private func setupPusher() {
        let options = PusherClientOptions(
            authMethod: .inline(secret: pusherSecret), // Only for development/demo
            host: .cluster(pusherCluster)
        )

        pusher = Pusher(key: pusherKey, options: options)

        pusher.connection.delegate = self

        // Subscribe to a private channel for this shareId (required for client events)
        channel = pusher.subscribe(channelName: "private-heartrate-\(shareId)")
    }

    func connect() {
        pusher.connect()
        print("📡 Connecting to Pusher...")
    }

    func disconnect() {
        pusher.disconnect()
        print("📡 Disconnected from Pusher")
    }

    func publishHeartRate(bpm: Int, timestamp: Date, source: String) {
        guard let channel = channel else {
            print("⚠️ Channel not available")
            return
        }

        // Rate limiting: only publish if enough time has passed
        let now = Date()
        if let lastPublish = lastPublishTime {
            let timeSinceLastPublish = now.timeIntervalSince(lastPublish)
            if timeSinceLastPublish < minimumPublishInterval {
                // Skip this publish - too soon
                return
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let data: [String: Any] = [
            "bpm": bpm,
            "timestamp": isoFormatter.string(from: timestamp),
            "source": source,
            "shareId": shareId
        ]

        // Trigger client event (requires client events to be enabled in Pusher dashboard)
        channel.trigger(eventName: "client-heartrate-update", data: data)

        // Update last publish time
        lastPublishTime = now

        print("📤 Published heart rate: \(bpm) BPM")
    }
}

extension PusherService: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        print("📡 Pusher connection: \(old.stringValue()) -> \(new.stringValue())")
        onConnectionStateChange?(new)
    }

    func subscribedToChannel(name: String) {
        print("✓ Subscribed to channel: \(name)")
    }

    func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
        print("⚠️ Failed to subscribe to channel \(name): \(error?.localizedDescription ?? "unknown error")")
    }

    func debugLog(message: String) {
        print("🔍 Pusher debug: \(message)")
    }
}
