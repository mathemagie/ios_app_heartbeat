import SwiftUI

struct ContentView: View {
    @State private var isStreaming = false
    private let streamer: HeartRateStreamer
    private let shareId: String

    init() {
        let hk = HealthKitManager()
        let shareId = ShareIdStore().loadOrCreate()
        let fb = FirebaseService(shareId: shareId)
        self.streamer = HeartRateStreamer(healthKit: hk, firebase: fb)
        self.shareId = shareId
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Heart Rate Streamer").font(.title)
            Text("Share ID: \(shareId)").font(.subheadline).textSelection(.enabled)
            Button(isStreaming ? "Stop" : "Start") {
                isStreaming.toggle()
                if isStreaming { streamer.start() }
            }
            Text("Grant Health permissions for Heart Rate in the next prompt.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }.padding()
    }
}


