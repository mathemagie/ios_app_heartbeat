# HeartBeatStream

Stream your heart rate live from an iPhone to the web. The iOS app reads heart
rate samples from Apple Health via HealthKit and broadcasts them through
[Pusher Channels](https://pusher.com) to a real-time web page.

```
HealthKit → HealthKitManager → HeartRateStreamer → PusherService
                                                        │
                                                  Pusher Channels
                                                        │
                                                   Web Client
```

## Project Layout

- `ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/` – SwiftUI app sources
  - `HealthKitManager.swift` – HealthKit authorization and heart rate observation
  - `HeartRateStreamer.swift` – Coordinates HealthKit data flow to UI and Pusher
  - `PusherService.swift` – Publishes BPM updates to a Pusher channel
  - `ContentView.swift` – Main UI displaying current BPM, status, and Share ID
  - `ShareIdStore.swift` – Generates and persists the unique Share ID
  - `AppDelegate.swift` – App initialization
- `web/index.html` – Real-time web listener (subscribes to the Pusher channel)
- `PUSHER_SETUP.md` – Full, detailed Pusher setup and troubleshooting guide

## How It Works

1. **iOS app (publisher):** requests HealthKit read access, observes new heart
   rate samples with `HKObserverQuery` + `HKAnchoredObjectQuery`, and publishes
   each reading to the Pusher channel `private-heartrate-{shareId}` via a
   `client-heartrate-update` event.
2. **Web client (subscriber):** subscribes to the same channel using the Share
   ID from the URL and updates the BPM display in real time.
3. **Pusher Channels:** routes messages between the app and the browser over
   WebSockets. No server code required.

Each install gets a unique 8-character **Share ID** (persisted in
`UserDefaults`) that defines its channel — anyone with the ID can view the
stream.

## Prerequisites

- **Xcode 15+**
- A **real iPhone** — HealthKit is limited in the Simulator
- A **Health data source** that writes heart rate (e.g., a paired Apple Watch)
- A free **Pusher account** ([pusher.com](https://pusher.com))

## Setup

### 1. Create a Pusher app

1. Sign up at [pusher.com](https://pusher.com) and **Create app** → Channels.
2. Pick a cluster (default in this repo is `eu`).
3. In **App Settings**, enable **Client Events** (required — the app publishes
   directly from the client).
4. From **App Keys**, copy your `key`, `secret`, and `cluster`.

### 2. Configure credentials

Set the same key/cluster in both places:

- `ios/.../PusherService.swift` (lines ~10–12): `pusherKey`, `pusherCluster`, `pusherSecret`
- `web/index.html` (lines ~311–313): `PUSHER_KEY`, `PUSHER_CLUSTER`, `PUSHER_SECRET`

### 3. Build the iOS app

1. Open the project in Xcode:
   ```bash
   xed ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj
   ```
2. Add the Pusher Swift SDK: **File → Add Package Dependencies…** →
   `https://github.com/pusher/pusher-websocket-swift.git` (version `10.1.9`),
   then add the **PusherSwift** library.
3. Run on a real iPhone (⌘R). Grant HealthKit permission, tap
   **Start Monitoring**, and note the **Share ID** shown in the UI.

   Or build from the CLI:
   ```bash
   xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build
   ```

   Or build for the iOS Simulator (run from the repo root):
   ```bash
   xcodebuild -project ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj \
     -scheme HeartBeatStream \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
   ```

   > **Note:** The Simulator has no heart-rate sensor, so live BPM stays at `--`.
   > Use it to test the UI (Share ID, copy button, Pusher connection); use a real
   > iPhone + Apple Watch for actual heart-rate data.

### 4. Open the web client

```bash
python3 -m http.server --directory web 8000
```

Then open `http://localhost:8000/`. The page shows the live Heart Nebula, which
breathes in time with the streamed BPM. (The old BPM monitor is at
`http://localhost:8000/index2.html`.) BPM should update live within a second or two.

> See `PUSHER_SETUP.md` for the full walkthrough, architecture details, and
> troubleshooting.

## ⚠️ Security Note

The current implementation embeds the Pusher **secret** directly in client code
(`PusherService.swift` and `web/index.html`) and signs channel auth in the
browser. A Pusher secret is meant to stay server-side — anyone who reads the
page source or this repo can use it to sign for any channel, so the "private"
channels are not actually protected.

This is acceptable for personal use. For anything shared:

- Regenerate the key/secret in the Pusher dashboard if it has been exposed.
- Move auth to a small server-side endpoint, or use plain public channels if
  privacy isn't required.

## Features

- **Real-time BPM display** with large, easy-to-read numbers
- **Connection status** indicators (Monitoring, Connecting, Failed, Stopped)
- **Data source** label (e.g., which Apple Watch provided the reading)
- **Last update time** for the most recent sample
- **Live web view** of the stream via Share ID
- **Rate limiting** — publishes at most once every 2 seconds to stay within
  Pusher free-tier limits

## Troubleshooting

**No heart rate data appearing:**
- Ensure the Health app has heart rate samples (from an Apple Watch or other source).
- Check permissions: Settings → Privacy & Security → Health → HeartBeatStream →
  enable "Allow to Read Data".
- Run on a real device, not the Simulator.

**iOS shows "disconnected" / build errors about PusherSwift:**
- Verify the `pusherKey` and `pusherCluster` are correct.
- Confirm the PusherSwift package was added (step 3.2).
- Try **Product → Clean Build Folder** (⇧⌘K) and rebuild.

**Web client stuck on "Waiting for data":**
- Open the browser console (F12) and check for errors.
- Confirm `PUSHER_KEY` / `PUSHER_CLUSTER` match the iOS app.
- Make sure the Share ID in the URL matches the one shown in the app, and that
  the app is running and connected.

For more, see the Troubleshooting section in `PUSHER_SETUP.md`.

## Privacy

- Heart rate data is read only from HealthKit, with explicit user permission.
- Data is streamed to Pusher and is viewable by anyone holding the Share ID.
- Rotate your Share ID by deleting and reinstalling the app.
