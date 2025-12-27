import SwiftUI

struct ContentView: View {
    @State private var isStreaming = false
    @State private var errorMessage: String?
    @State private var connectionStatus: String = "Not Connected"
    @State private var currentBPM: Int? = nil
    @State private var lastUpdateTime: Date? = nil
    @State private var dataSource: String = ""

    private let streamer: HeartRateStreamer

    init() {
        let hk = HealthKitManager()
        self.streamer = HeartRateStreamer(healthKit: hk)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Heart Rate Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)

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
                        DispatchQueue.main.async {
                            currentBPM = bpm
                            lastUpdateTime = date
                            dataSource = source
                            if connectionStatus == "Connecting..." {
                                connectionStatus = "Monitoring"
                            }
                        }
                    }
                    streamer.start { success, error in
                        DispatchQueue.main.async {
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
        }
        .padding()
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
}
