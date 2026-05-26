import SwiftUI
import UIKit
import PusherSwift

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
    private let shareId: String

    init() {
        let hk = HealthKitManager()
        let shareIdStore = ShareIdStore()
        let shareId = shareIdStore.loadOrCreate()
        self.shareId = shareId

        // Create Pusher service
        let pusherService = PusherService(shareId: shareId)

        // Create streamer with Pusher integration
        self.streamer = HeartRateStreamer(healthKit: hk, pusherService: pusherService)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Heart Rate Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Share ID Display
            VStack(spacing: 10) {
                Text("SHARE ID")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Button {
                    copyShareId()
                } label: {
                    HStack(spacing: 10) {
                        Text(shareId)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Image(systemName: didCopyShareId ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.title3)
                            .foregroundStyle(didCopyShareId ? .green : .accentColor)
                    }
                }
                .buttonStyle(.plain)

                Text(didCopyShareId ? "Copied!" : "Tap to copy")
                    .font(.caption2)
                    .foregroundStyle(didCopyShareId ? .green : .secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(pusherStatusColor)
                        .frame(width: 6, height: 6)
                    Text("Pusher: \(pusherStatus)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(connectionStatus)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
            }

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
                    streamer.onPusherConnectionChange = { (state: ConnectionState) in
                        Task { @MainActor in
                            pusherStatus = state.stringValue()
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

            Text("Requires HealthKit permission for heart rate data from Apple Watch or other devices")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
                    streamer.onPusherConnectionChange = { (state: ConnectionState) in
                        Task { @MainActor in
                            pusherStatus = state.stringValue()
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
        UIPasteboard.general.string = shareId
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

    private var statusColor: Color {
        switch connectionStatus {
        case "Monitoring", "Connected":
            return .green
        case "Connecting...":
            return .orange
        case "Failed", "Stopped":
            return .red
        default:
            return .gray
        }
    }

    private var pusherStatusColor: Color {
        switch pusherStatus {
        case "connected":
            return .green
        case "connecting", "reconnecting":
            return .orange
        case "disconnected", "disconnecting":
            return .gray
        default:
            return .red
        }
    }
}
