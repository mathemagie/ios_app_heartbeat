# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

**iOS App:**
- Open in Xcode: `xed ios/HeartBeatStream`
- Build via CLI: `xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build`
- Run on simulator: `xcodebuild -scheme HeartBeatStream -destination 'platform=iOS Simulator,name=iPhone 15' test`
- **Note:** HealthKit requires a real iOS device with heart rate data (e.g., from Apple Watch). Simulator testing is limited.

**Web Client:**
- Serve locally: `python3 -m http.server --directory web 8000`
- Access at: `http://localhost:8000/index.html?share=YOUR_SHARE_ID`
- Replace `firebaseConfig` in `web/index.html` with actual Firebase Web config before testing

**Firebase:**
- Deploy database rules: `firebase deploy --only database`
- Requires `firebase login` to be run once per machine

## Architecture Overview

This is a heart rate streaming system with three components:

### 1. iOS App (SwiftUI)
- **HealthKitManager.swift**: Manages HealthKit authorization and observes heart rate samples using `HKObserverQuery` and `HKAnchoredObjectQuery`. Supports background delivery for continuous monitoring.
- **HeartRateStreamer.swift**: Coordinates HealthKit data flow. Currently passes heart rate updates to UI via callback (`onHeartRateUpdate`). Originally designed to send data to Firebase (see note below).
- **ContentView.swift**: SwiftUI view displaying current BPM, last update time, and data source. Manages streaming state and error handling.
- **ShareIdStore.swift**: Generates and persists an 8-character share ID in `UserDefaults` for public stream identification.
- **AppDelegate.swift**: App initialization point (Firebase integration currently removed).

**Data Flow:**
1. HealthKit samples arrive via observer → `HealthKitManager`
2. Samples converted to BPM int → `HeartRateStreamer`
3. Callback updates UI → `ContentView`

**Note:** Firebase integration has been removed from the iOS app. The README and AGENTS.md still reference Firebase paths (`users/{uid}/heartRate/*` and `publicStreams/{shareId}/latest`), but the current implementation only displays heart rate in the UI. To re-enable Firebase streaming, restore Firebase SDK dependencies and implement write logic in `HeartRateStreamer` or create a new `FirebaseService.swift`.

### 2. Web Client (Vanilla JS)
- Static HTML page using Firebase JS SDK (v9 modular)
- Listens to `publicStreams/{shareId}/latest` for real-time BPM updates
- Share ID passed via query parameter: `?share=YOUR_ID`

### 3. Firebase Backend (Not Currently Active)
- **Expected Schema** (from documentation, not currently being written to):
  - `users/{uid}/heartRate/{timestamp}`: Private user data
  - `publicStreams/{shareId}/latest`: Public stream for sharing
  - `publicStreams/{shareId}/heartRate/{timestamp}`: Public stream history
- **Rules** (referenced but file not present): World-readable public streams, auth-restricted user paths

## Key Implementation Details

**HealthKit Query Pattern:**
- Uses `HKObserverQuery` to detect new samples
- `HKAnchoredObjectQuery` with persistent anchor to fetch only new samples since last query
- Background delivery enabled with `.immediate` frequency
- Initial fetch on start to deliver recent data immediately

**Share ID:**
- Generated once per app install (8-char lowercase UUID prefix)
- Stored in `UserDefaults` under key `publicShareId`
- Used to create world-readable Firebase path for sharing heart rate with web client

**SwiftUI State Management:**
- `ContentView` owns streaming state (`isStreaming`, `currentBPM`, `connectionStatus`)
- Callback-based updates from `HeartRateStreamer` to UI via `onHeartRateUpdate`
- All UI updates dispatched to main queue

## Firebase Integration (Currently Disabled)

The README describes a complete Firebase integration that is **not currently implemented** in the iOS code:

**To Re-enable Firebase:**
1. Add Firebase SDK via SPM: `https://github.com/firebase/firebase-ios-sdk`
   - Select: `FirebaseCore`, `FirebaseAuth`, `FirebaseDatabase`
2. Add `GoogleService-Info.plist` to Xcode target (excluded from git)
3. Restore Firebase initialization in `AppDelegate.swift`
4. Implement anonymous auth and database writes (create `FirebaseService.swift` or modify `HeartRateStreamer`)
5. Write to both private (`users/{uid}/heartRate/{timestamp}`) and public (`publicStreams/{shareId}/latest`) paths
6. Create and deploy `firebase/database.rules.json` with appropriate read/write rules

**Database Rules Pattern (from README):**
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
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

## Project Structure

```
ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/
├── AppDelegate.swift          # App entry point
├── ContentView.swift           # Main UI
├── HealthKitManager.swift      # HealthKit queries & authorization
├── HeartRateStreamer.swift     # Coordination layer
├── ShareIdStore.swift          # Share ID persistence
└── HeartBeatStream.entitlements # HealthKit capability

web/
└── index.html                  # Firebase web listener

firebase/                        # (Directory not present)
└── database.rules.json         # (File referenced but not present)
```

## Swift Code Patterns

- Use `final` classes when no subclassing is needed
- 4-space indentation
- Protocol-oriented design for testability (consider extracting protocols if adding tests)
- Error handling via custom `enum` errors with `localizedDescription`
- Weak self captures in closures to prevent retain cycles
- Explicit type annotations for clarity in manager classes

## Testing & Validation

**Device Testing:**
1. Build and run on real iPhone with paired Apple Watch
2. Start monitoring in app
3. Verify BPM updates appear in UI with source name
4. Check that background delivery continues when app is backgrounded (iOS may defer)

**Future Unit Tests:**
- Create test target under `ios/HeartBeatStreamTests/`
- Run: `xcodebuild -scheme HeartBeatStream -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Mock `HKHealthStore` for HealthKit testing
- Mock Firebase for database write testing (when re-enabled)

**Web Client Testing (when Firebase is active):**
1. Run iOS app and note Share ID from UI
2. Serve web client: `python3 -m http.server --directory web 8000`
3. Open `http://localhost:8000/index.html?share={SHARE_ID}`
4. Verify BPM updates appear on webpage
5. Validate via Firebase Console that data appears under `publicStreams/{shareId}/latest`

## Security & Configuration

- **Never commit:** `GoogleService-Info.plist`, Firebase credentials, API keys
- Share ID is sensitive: treat as capability URL (anyone with ID can view stream)
- Rotate share ID by clearing app data or deleting/reinstalling app
- Firebase rules must enforce auth requirement for writes, public read for `publicStreams`
- Private user data (`users/{uid}`) must stay auth-restricted

## Code Style

- `PascalCase` for types, `camelCase` for functions/properties
- Suffix manager classes with role: `HealthKitManager`, `FirebaseService` (when added)
- Web code: double-quoted HTML attributes, kebab-case CSS classes, minimal inline scripts
- Centralize Firebase path strings in helper methods when implementing Firebase integration
