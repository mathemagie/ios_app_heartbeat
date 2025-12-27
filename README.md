# HeartBeatStream

Native iOS app that reads heart rate data from Apple Health using HealthKit and displays it in real-time.

## Project Layout

- `ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/` – SwiftUI app sources
  - `HealthKitManager.swift` – HealthKit authorization and heart rate observation
  - `HeartRateStreamer.swift` – Coordinates HealthKit data flow to UI
  - `ContentView.swift` – Main UI displaying current BPM and status
  - `AppDelegate.swift` – App initialization
  - `ShareIdStore.swift` – Share ID generation and persistence
- `web/index.html` – Web listener (currently references Firebase; integration pending)

## Prerequisites

- **Xcode 15+** and a **real iPhone** (HealthKit is limited in Simulator)
- A **Health data source** (e.g., Apple Watch; AirPods if they write HR into Health)
- **iOS device** with HealthKit enabled

## iOS Setup

1. **Open the project in Xcode:**
   ```bash
   xed ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj
   ```

2. **HealthKit Capability:**
   - The project includes `HeartBeatStream.entitlements` with HealthKit read access
   - The `NSHealthShareUsageDescription` is configured in the project settings

3. **Build and Run:**
   ```bash
   xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build
   ```
   Or run directly from Xcode on a real iOS device.

## How It Works

The app:
- Requests HealthKit read permission for heart rate data on first launch
- Uses `HKObserverQuery` to detect new heart rate samples
- Uses `HKAnchoredObjectQuery` to fetch only new samples since the last query
- Displays the current BPM, last update time, and data source in the UI
- Supports background delivery for continuous monitoring

**Note:** HealthKit background delivery can wake the app, but iOS may defer updates when the app is in the background. Start testing with the app in the foreground.

## Features

- **Real-time Heart Rate Display** – Shows current BPM with large, easy-to-read numbers
- **Status Indicators** – Visual feedback for connection status (Monitoring, Connecting, Failed, Stopped)
- **Data Source Information** – Displays which device provided the heart rate data (e.g., Apple Watch)
- **Last Update Time** – Shows when the most recent heart rate reading was received

## Troubleshooting

- **No heart rate data appearing:**
  - Ensure Health app has heart rate samples (from Apple Watch or other source)
  - Check that HealthKit permissions were granted (go to Settings > Privacy & Security > Health)
  - Verify the app is running on a real iOS device (not Simulator)
  
- **Permissions denied:**
  - Go to Settings > Privacy & Security > Health > HeartBeatStream
  - Enable "Allow HealthKit to Read Data"

## Project Structure Details

### Key Components

**HealthKitManager.swift**
- Handles HealthKit authorization
- Implements observer and anchored queries for efficient data retrieval
- Manages background delivery configuration

**HeartRateStreamer.swift**
- Coordinates between HealthKitManager and UI
- Provides callback-based updates to ContentView
- Converts HealthKit samples to BPM values

**ContentView.swift**
- SwiftUI interface with large BPM display
- Start/Stop monitoring controls
- Status and error message display

**ShareIdStore.swift**
- Generates and persists a unique share ID using UserDefaults
- Currently unused (prepared for future Firebase integration)

## Future Enhancements

Firebase integration for streaming heart rate data to a web client is planned but not currently implemented. When added, it will:
- Stream heart rate data to Firebase Realtime Database
- Enable web clients to view real-time heart rate via share ID
- Store private user data and public streams

## Privacy

- All heart rate data stays on the device
- HealthKit permissions are requested only for reading heart rate data
- No data is transmitted to external servers in the current implementation
