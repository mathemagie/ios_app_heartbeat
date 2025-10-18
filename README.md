# HeartBeatStream

Native iOS app that reads heart rate from Apple Health and streams it to Firebase Realtime Database for a website to display in near real time.

## Project layout
- `ios/HeartBeatStream/` – SwiftUI app sources (HealthKit in `HealthKitManager.swift`, Firebase in `FirebaseService.swift`)
- `web/index.html` – Static web listener that shows latest BPM
- `firebase/database.rules.json` – Realtime Database security rules
- `plan.md` – High‑level architecture

## Prerequisites
- Xcode 15+ and a real iPhone (HealthKit is limited in Simulator)
- A Health data source (e.g., Apple Watch; AirPods if they write HR into Health)
- Firebase project with Realtime Database and Anonymous Auth enabled

## iOS setup
1. In Firebase Console, add an iOS app and download `GoogleService-Info.plist` (do not commit). Add it to the `HeartBeatStream` target in Xcode.
2. Add HealthKit capability to the target.
3. Add `NSHealthShareUsageDescription` to Info.plist (why you need Heart Rate).
4. Add Firebase via Swift Package Manager: `https://github.com/firebase/firebase-ios-sdk` (select `FirebaseCore`, `FirebaseAuth`, `FirebaseDatabase`).
5. Open sources: `xed ios/HeartBeatStream`.
6. Build: `xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build` or run from Xcode on a real device.

The app will:
- Configure Firebase and sign in anonymously on launch (`AppDelegate.swift`).
- Request HealthKit read permission for heart rate (`HealthKitManager.swift`).
- Observe new heart rate samples and write to Firebase under:
  - `users/{uid}/heartRate/{timestamp}` (private)
  - `publicStreams/{shareId}/latest` and `/heartRate/{timestamp}` (public share)
- Show the generated `shareId` in the UI (`ContentView.swift`).

## Web listener
1. Edit `web/index.html` and replace `firebaseConfig` with your Firebase Web config from Console.
2. Quick serve: `python3 -m http.server --directory web 8000`.
3. Open `http://localhost:8000/index.html?share=YOUR_SHARE_ID` (use the Share ID shown in the app).

The page listens to `publicStreams/{shareId}/latest` and updates the DOM with the latest BPM.

## Realtime Database rules
Example rules are in `firebase/database.rules.json`:
- `users/{uid}`: read/write only by that authenticated user
- `publicStreams/{shareId}`: world‑readable, writeable only by authenticated app

Deploy them with:

```bash
firebase deploy --only database
```

(Requires `firebase login` within this repo.)

## Notes & troubleshooting
- HealthKit background delivery can wake the app, but iOS may defer network writes; start testing with the app in foreground.
- If you see no data:
  - Ensure Health has heart rate samples (from Watch or other source).
  - Confirm `GoogleService-Info.plist` is in the target and Firebase SDKs are added.
  - Verify Anonymous Auth and Realtime Database are enabled in Firebase.
  - Check you updated `firebaseConfig` in `web/index.html` and used the correct `share` parameter.

## Privacy
- Private user data stays under `users/{uid}` per Firebase rules.
- Public stream (`publicStreams/{shareId}`) is intentionally world‑readable for sharing. Rotate the `shareId` to stop sharing.


