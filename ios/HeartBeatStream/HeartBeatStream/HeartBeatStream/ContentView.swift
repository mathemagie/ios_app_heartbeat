import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var connectionStatus: String = "Not Connected"
    @State private var pusherStatus: String = "Disconnected"
    @State private var currentBPM: Int? = nil
    @State private var lastUpdateTime: Date? = nil
    @State private var dataSource: String = ""
    @State private var didCopyShareId = false

    private let streamer: HeartRateStreamer

    // Single global stream — no per-user ID. The web viewer lives at this URL.
    private let streamURL = "https://project-56opg.vercel.app"
    private let shareId = "live"

    init() {
        let hk = HealthKitManager()

        // Create Pusher service for the single global stream
        let pusherService = PusherService(shareId: shareId)

        // Create streamer with Pusher integration
        self.streamer = HeartRateStreamer(healthKit: hk, pusherService: pusherService)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Heart Rate Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Live stream link
            VStack(spacing: 10) {
                Text("LIVE STREAM")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Button {
                    copyShareId()
                } label: {
                    HStack(spacing: 10) {
                        Text(streamURL.replacingOccurrences(of: "https://", with: ""))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Image(systemName: didCopyShareId ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.title3)
                            .foregroundStyle(didCopyShareId ? .green : .accentColor)
                    }
                }
                .buttonStyle(.plain)

                if didCopyShareId {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                // One status line for the whole "is my heart reaching the web?"
                // question — replaces the two competing connection vocabularies.
                HStack(spacing: 6) {
                    if streamStatus.connecting {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Circle()
                            .fill(streamStatus.color)
                            .frame(width: 6, height: 6)
                    }
                    Text(streamStatus.label)
                        .font(.caption2)
                        .foregroundStyle(streamStatus.color)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            // Heart Rate Display
            VStack(spacing: 15) {
                if let bpm = currentBPM {
                    // Large BPM display
                    VStack(spacing: 8) {
                        Text("\(bpm)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                        Text("BPM")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    
                    // Last update info
                    if let updateTime = lastUpdateTime {
                        VStack(spacing: 4) {
                            Text("Last update: \(formatTime(updateTime))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !dataSource.isEmpty {
                                Text("Source: \(dataSource)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("--")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("Start monitoring to see your heart rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minHeight: 200)

            // Error display
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
            }

            // Start/Stop button
            Button(isStreaming ? "Stop Monitoring" : "Start Monitoring") {
                if isStreaming {
                    streamer.stop()
                    isStreaming = false
                    connectionStatus = "Stopped"
                    currentBPM = nil
                    errorMessage = nil
                } else {
                    connectionStatus = "Connecting..."
                    errorMessage = nil

                    // Set up callback to receive heart rate updates
                    streamer.onHeartRateUpdate = { bpm, date, source in
                        Task { @MainActor in
                            currentBPM = bpm
                            lastUpdateTime = date
                            dataSource = source
                            if connectionStatus == "Connecting..." {
                                connectionStatus = "Monitoring"
                            }
                        }
                    }

                    // Set up Pusher connection state callback
                    streamer.onPusherConnectionChange = { (state: UploadState) in
                        Task { @MainActor in
                            pusherStatus = state.rawValue
                        }
                    }

                    streamer.start { success, error in
                        Task { @MainActor in
                            if success {
                                isStreaming = true
                                connectionStatus = "Monitoring"
                            } else {
                                connectionStatus = "Failed"
                                if let error = error {
                                    errorMessage = error.localizedDescription
                                } else {
                                    errorMessage = "Unknown error occurred"
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Only instructive while idle; once BPM flows it's just noise.
            if currentBPM == nil {
                Text("Requires HealthKit permission for heart rate data from Apple Watch or other devices")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            #if DEBUG
            // Simulator helper: feeds random BPM into the UI + Pusher,
            // bypassing HealthKit (which has no sensor in the Simulator).
            Button(isStreaming ? "Stop Mock Data" : "Simulate Heart Rate (Debug)") {
                if isStreaming {
                    streamer.stop()
                    isStreaming = false
                    connectionStatus = "Stopped"
                    currentBPM = nil
                    errorMessage = nil
                } else {
                    errorMessage = nil
                    connectionStatus = "Connecting..."

                    streamer.onHeartRateUpdate = { bpm, date, source in
                        Task { @MainActor in
                            currentBPM = bpm
                            lastUpdateTime = date
                            dataSource = source
                            connectionStatus = "Monitoring (Mock)"
                        }
                    }
                    streamer.onPusherConnectionChange = { (state: UploadState) in
                        Task { @MainActor in
                            pusherStatus = state.rawValue
                        }
                    }
                    streamer.startMock { success, _ in
                        Task { @MainActor in
                            isStreaming = success
                            connectionStatus = success ? "Monitoring (Mock)" : "Failed"
                        }
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            #endif
        }
        .padding()
    }
    
    private func copyShareId() {
        UIPasteboard.general.string = streamURL
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation {
            didCopyShareId = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                didCopyShareId = false
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// The single source of truth for "is my heart reaching the web?".
    /// Folds the iOS connection state and the raw Pusher upload state into
    /// one human-readable line, translating engineer-speak (ok/sending/idle)
    /// into language the viewer cares about.
    private var streamStatus: (label: String, color: Color, connecting: Bool) {
        if connectionStatus == "Failed" {
            return ("Couldn't connect", .red, false)
        }
        // Idle and not mid-connect.
        if !isStreaming && connectionStatus != "Connecting..." {
            return ("Not streaming", .gray, false)
        }
        switch pusherStatus {
        case UploadState.ok.rawValue, UploadState.sending.rawValue:
            // An in-flight upload means we're live — don't flicker to
            // "Connecting…" on every 2s publish round-trip.
            return ("Live on the web", .green, false)
        case UploadState.error.rawValue:
            return ("Reconnecting…", .orange, true)
        default: // idle / Disconnected — before the first send lands
            return ("Connecting…", .orange, true)
        }
    }
}
