<!-- 77b3d618-7114-4f8d-9bb0-9b4f2a91dfc6 1aad4b99-b796-496c-8e0b-bb31f803377c -->
# iOS Health HeartRate → Firebase Realtime DB Real-time Stream

## Overview

- iOS app (SwiftUI) reads heart rate from HealthKit and observes new samples.
- App signs in to Firebase anonymously and writes samples to:
  - `users/{uid}/heartRate/{timestampKey}` (private per-user history)
  - `publicStreams/{shareId}/latest` and `publicStreams/{shareId}/heartRate/{timestampKey}` (for live sharing + optional history)
- Website (static HTML/JS) uses Firebase JS SDK to listen on `publicStreams/{shareId}` in real time.
- Note: Update timing depends on when HealthKit persists samples from the source (AirPods). Near‑real‑time, not sub‑second live guaranteed.

## Architecture

- iOS (HealthKit + FirebaseAuth + FirebaseDatabase) → Firebase Realtime Database → Website (Firebase JS SDK listener)

## Firebase Setup

1. Create a Firebase project.
2. Enable Realtime Database (locked mode), pick a location.
3. Enable Authentication → Anonymous provider.
4. Add an iOS app in Firebase console; download `GoogleService-Info.plist` and add to Xcode target.
5. Add Firebase SDK using Swift Package Manager: `https://github.com/firebase/firebase-ios-sdk` (select `FirebaseCore`, `FirebaseAuth`, `FirebaseDatabase`).

## iOS App (Swift)

- Project: `ios/HeartBeatStream.xcodeproj`
- Tech: Swift 5+, SwiftUI, HealthKit, Firebase (Auth, Database)
- Capabilities:
  - Enable `HealthKit` capability
  - Info.plist: `NSHealthShareUsageDescription`
- Files to add/update:
  - `ios/HeartBeatStream/HealthKitManager.swift` (as before; HK auth + queries)
  - `ios/HeartBeatStream/AppDelegate.swift` (Firebase configure + anonymous sign-in)
  - `ios/HeartBeatStream/ShareIdStore.swift` (persist short public shareId)
  - `ios/HeartBeatStream/FirebaseService.swift` (writes to DB)
  - `ios/HeartBeatStream/HeartRateStreamer.swift` (pipe HealthKit → Firebase)
  - `ios/HeartBeatStream/ContentView.swift` (toggle + show shareId)

### App delegate: Firebase configure + anonymous auth

```swift
import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    if Auth.auth().currentUser == nil {
      Auth.auth().signInAnonymously { _, _ in }
    }
    return true
  }
}

@main
struct HeartBeatStreamApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene { WindowGroup { ContentView() } }
}
```

### ShareId persistence (for public stream)

```swift
import Foundation

final class ShareIdStore {
  private let key = "publicShareId"
  func loadOrCreate() -> String {
    if let existing = UserDefaults.standard.string(forKey: key) { return existing }
    let newId = String(UUID().uuidString.prefix(8)).lowercased()
    UserDefaults.standard.set(newId, forKey: key)
    return newId
  }
}
```

### Firebase writer

```swift
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
    // Private history
    db.child("users/\(uid)/heartRate/\(ts)").setValue(sample)
    // Public live + history
    db.child("publicStreams/\(shareId)/latest").setValue(sample)
    db.child("publicStreams/\(shareId)/heartRate/\(ts)").setValue(sample)
  }
}
```

### Heart rate streamer (HealthKit → Firebase)

```swift
import HealthKit

final class HeartRateStreamer {
  private let hk: HealthKitManager
  private let firebase: FirebaseService

  init(healthKit: HealthKitManager, firebase: FirebaseService) {
    self.hk = healthKit
    self.firebase = firebase
  }

  func start() {
    hk.requestAuthorization { [weak self] granted, _ in
      guard granted else { return }
      self?.hk.startObservingHeartRate { [weak self] samples in
        guard let self else { return }
        for s in samples {
          let bpm = s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
          self.firebase.writeHeartRate(
            bpm: Int(round(bpm)),
            start: s.startDate,
            end: s.endDate,
            source: s.sourceRevision.source.name
          )
        }
      }
    }
  }
}
```

### SwiftUI minimal UI (shows share link)

```swift
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
```

Notes:

- Background sending depends on iOS background execution limits. Start with foreground. HealthKit background delivery can wake the app, but network writes may be deferred by the system.

## Website (listener)

- Files: `web/index.html`
- Use Firebase JS SDK v9. Replace `YOUR_...` with your Firebase web config.
- Reads from `publicStreams/{shareId}/latest`.
```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Heart Rate Live</title>
    <style> body { font-family: system-ui, sans-serif; } #bpm { font-size: 40px; } </style>
    <script type="module">
      import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.23.0/firebase-app.js'
      import { getDatabase, ref, onValue } from 'https://www.gstatic.com/firebasejs/9.23.0/firebase-database.js'

      const firebaseConfig = {
        apiKey: 'YOUR_API_KEY',
        authDomain: 'YOUR_AUTH_DOMAIN',
        databaseURL: 'YOUR_DB_URL',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: 'YOUR_BUCKET',
        messagingSenderId: 'YOUR_SENDER',
        appId: 'YOUR_APP_ID'
      }

      const app = initializeApp(firebaseConfig)
      const db = getDatabase(app)

      const params = new URLSearchParams(location.search)
      const shareId = params.get('share') || 'demo'
      const latestRef = ref(db, `publicStreams/${shareId}/latest`)

      onValue(latestRef, (snap) => {
        const data = snap.val()
        document.getElementById('bpm').textContent = data ? `${data.bpm} bpm` : '—'
        document.getElementById('meta').textContent = data ? `${data.source} @ ${data.end}` : ''
      })
    </script>
  </head>
  <body>
    <h1>Heart Rate</h1>
    <div id="bpm">—</div>
    <div id="meta" style="color:#666"></div>
    <p>Use URL like: <code>?share=YOUR_SHARE_ID</code></p>
  </body>
</html>
```


## Realtime Database Security Rules (example)

- Private user data locked to the authenticated user; public streams are world-readable, app-writeable.
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    },
    "publicStreams": {
      "$shareId": {
        ".read": true,
        ".write": "auth != null"
      }
    }
  }
}
```


## Testing

1. Firebase Console: enable Anonymous auth, set the rules above.
2. iOS: run on a real device. On first launch, allow Health permission; verify writes in Realtime Database console under `users/{uid}` and `publicStreams/{shareId}`.
3. Web: open `web/index.html?share=YOUR_SHARE_ID` with your project config; observe live BPM updates.

## Deployment notes

- Host the website (Firebase Hosting or any static host). Config keys are public identifiers; security rules protect data.
- To stop sharing, rotate `shareId` (generate a new one).
- For history charts, read `publicStreams/{shareId}/heartRate` and plot a time series.

## Privacy

- Explain data use in the app; only write heart rate and minimal metadata.
- Keep user-scoped data private; public path is intentionally shareable.

### To-dos

- [ ] Create SwiftUI project with HealthKit capability and Info.plist usage string
- [ ] Implement HealthKit authorization for heart rate read
- [ ] Add HKObserverQuery + HKAnchoredObjectQuery for heart rate updates
- [ ] Implement URLSessionWebSocketTask client and connect to server
- [ ] Pipe new heart rate samples to WebSocket JSON payloads
- [ ] Create Node ws server that broadcasts messages
- [ ] Create simple website that displays latest BPM from websocket
- [ ] Run server, app, website; verify data flows end-to-end
- [ ] Explore background delivery limits and improve resilience (buffer/retry)
- [ ] Host Node server with TLS and switch clients to wss