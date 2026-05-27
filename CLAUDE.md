# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

**iOS App:**
- Open in Xcode: `xed ios/HeartBeatStream`
- Build via CLI: `xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build`
- **Build, install & launch on simulator:** `./scripts/run-simulator.sh` (optional arg picks the device, e.g. `./scripts/run-simulator.sh "iPhone 16"`)
- **Note:** HealthKit requires a real iOS device with a heart rate source (AirPods Pro 3 in-ear sensor, or a paired Apple Watch). The Simulator has no heart-rate sensor, so live BPM stays at `--`; use it only to test UI and the Pusher connection.

**Web Client:**
- Serve locally: `python3 -m http.server --directory web 8000`
- Nebula page (default): `http://localhost:8000/index.html`
- Production: deployed on Vercel; the web page fetches the public Pusher key from `/api/config`.

**Backend (Vercel serverless):**
- Functions live in `api/` (`heartbeat.py`, `config.py`).
- Pusher credentials are set as Vercel environment variables (`PUSHER_APP_ID`, `PUSHER_KEY`, `PUSHER_SECRET`, `PUSHER_CLUSTER`). The **secret never ships to clients**.

## Architecture Overview

This is a real-time heart rate streaming system: heart rate is captured on iOS via HealthKit, POSTed to a Vercel serverless function, published to a public Pusher channel, and rendered live in the browser (a "nebula" visualization that beats in sync with the heart).

### Data Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│  iPhone + AirPods Pro 3 (or Apple Watch)                               │
│                                                                        │
│   ❤️  AirPods heartbeat sensor (in-ear PPG)                            │
│        │ heart rate samples                                            │
│        ▼                                                               │
│   ┌─────────────────────┐   HKObserverQuery + HKAnchoredObjectQuery    │
│   │ HealthKitManager    │   (only new samples, background delivery)    │
│   └─────────┬───────────┘                                              │
│             │ bpm, timestamp, source                                   │
│             ▼                                                          │
│   ┌─────────────────────┐                                             │
│   │ HeartRateStreamer   ├──► onHeartRateUpdate ──► ContentView (UI)    │
│   └─────────┬───────────┘                                             │
│             ▼                                                          │
│   ┌─────────────────────┐   rate-limited: max 1 publish / 2 sec       │
│   │ PusherService       │                                             │
│   └─────────┬───────────┘                                             │
└─────────────┼──────────────────────────────────────────────────────── ┘
              │  HTTPS POST /api/heartbeat
              │  { bpm, timestamp(ISO8601), source, shareId:"live" }
              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  VERCEL SERVERLESS  (holds the Pusher SECRET — never the client)       │
│   api/heartbeat.py        api/config.py                                │
│   ─ validate bpm 20–300   ─ GET → { key, cluster }                     │
│   ─ pusher.trigger(...)     (public key only, no secret)               │
└─────────────┼──────────────────────────────────────────────────────── ┘
              │  Pusher REST API
              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PUSHER CHANNELS  (public — no auth)                                   │
│     channel: "heartrate-live"                                          │
│     event:   "heartrate-update"                                        │
│     payload: { bpm, timestamp, source, shareId }                       │
└─────────────┼──────────────────────────────────────────────────────── ┘
              │  WebSocket (real-time push)
              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  WEB CLIENTS (vanilla JS)                                              │
│   1. fetch /api/config → { key, cluster }                              │
│   2. new Pusher(key,{cluster}) → subscribe("heartrate-live")           │
│   3. bind("heartrate-update", data => setHeartRate(data.bpm))          │
│                                                                        │
│   index.html → / (Nebula)                                             │
│   period = 60/bpm sec drives the CSS @keyframes pulse                  │
│   (lub ~14%, dub ~34%); a synthesized lub-dub sound can be toggled     │
└──────────────────────────────────────────────────────────────────────┘
```

One line: `AirPods/Watch → HealthKit → iOS app → HTTPS POST → Vercel → Pusher → WebSocket → browser nebula`.

### 1. iOS App (SwiftUI)
- **HealthKitManager.swift**: Manages HealthKit authorization and observes heart rate samples using `HKObserverQuery` + `HKAnchoredObjectQuery` (anchored so only new samples are fetched). Supports background delivery for continuous monitoring. The heart rate source can be AirPods Pro 3 (in-ear PPG sensor) or an Apple Watch — both surface through HealthKit identically.
- **HeartRateStreamer.swift**: Coordination layer. Forwards each BPM update to the UI via `onHeartRateUpdate` **and** to `PusherService` for publishing.
- **PusherService.swift**: POSTs `{ bpm, timestamp, source, shareId }` to `/api/heartbeat` on the Vercel base URL via `URLSession`. Rate-limited to max one publish every 2 seconds.
- **ContentView.swift**: SwiftUI view displaying current BPM, last update time, data source, and connection status. Owns streaming state and error handling.
- **ShareIdStore.swift**: Generates/persists an 8-char share ID in `UserDefaults`. NOTE: the current stream uses a hard-coded `shareId = "live"`; per-user share IDs are not yet wired into the publish path.

### 2. Web Client (Vanilla JS)
- **web/index.html** → served at `/` (default): the **Nebula** visualization. Subscribes to Pusher and drives a breathing nebula animation. On each update it sets CSS `animation-duration = 60/bpm` seconds so the visuals beat at the real heart rate, using a two-peak lub-dub `@keyframes pulse` (systolic peak ~14% of cycle, diastolic ~34%) over brightness/saturation/hue/scale filters. A synthesized lub-dub heartbeat sound (Web Audio) can be toggled on.
- **web/nebula.js**: pure, DOM-free helpers (BPM clamping, period math, the pulse curve, beat timing, validation) shared by the page and the unit tests. UMD: `window.Nebula` in the browser, `require()` in Node.
- The page fetches the public Pusher key/cluster from `/api/config` (with a hard-coded public-key fallback), then `subscribe("heartrate-live")` and `bind("heartrate-update", …)`. Clients never see the Pusher secret.

### 3. Backend (Vercel Serverless, Python)
- **api/heartbeat.py** (`POST /api/heartbeat`): validates `shareId` and `bpm` (20–300 range), then calls `pusher.trigger("heartrate-live", "heartrate-update", { bpm, timestamp, source, shareId })`.
- **api/config.py** (`GET /api/config`): returns `{ key, cluster }` only — the public Pusher key and cluster. The secret stays in env vars.

## Key Implementation Details

**HealthKit Query Pattern:**
- `HKObserverQuery` detects new samples; `HKAnchoredObjectQuery` with a persistent anchor fetches only samples since the last query.
- Background delivery enabled with `.immediate` frequency; an initial fetch on start delivers recent data immediately.

**Single global stream:**
- Both iOS (`PusherService`) and the web pages hard-code `shareId = "live"`. There is currently one shared public stream — no per-user separation.

**Rate limiting:**
- `PusherService` publishes at most once every 2 seconds; the server additionally validates BPM is within 20–300 before triggering.

**SwiftUI State Management:**
- `ContentView` owns streaming state (`isStreaming`, `currentBPM`, `connectionStatus`).
- Updates flow from `HeartRateStreamer` to UI via `onHeartRateUpdate`; all UI updates dispatched to the main queue.

## Project Structure

```
ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/
├── AppDelegate.swift           # App entry point
├── ContentView.swift           # Main UI
├── HealthKitManager.swift      # HealthKit queries & authorization
├── HeartRateStreamer.swift     # Coordination layer (UI + publish)
├── PusherService.swift         # POSTs BPM to /api/heartbeat
├── ShareIdStore.swift          # Share ID persistence
└── HeartBeatStream.entitlements # HealthKit capability

api/
├── heartbeat.py                # POST /api/heartbeat → Pusher trigger
└── config.py                   # GET /api/config → public key + cluster

web/
├── index.html                  # / — Nebula visualization (default)
└── nebula.js                   # pure helpers shared by the page and tests
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
1. Build and run on a real iPhone with a heart rate source connected (AirPods Pro 3 or a paired Apple Watch).
2. Start monitoring in the app.
3. Verify BPM updates appear in the UI with the source name.
4. Open the web nebula page and confirm it beats in sync.
5. Check that background delivery continues when the app is backgrounded (iOS may defer).

**Web Client Testing:**
1. Run the iOS app and start monitoring.
2. Serve the web client: `python3 -m http.server --directory web 8000` (or use the Vercel deployment).
3. Open `http://localhost:8000/index.html` (nebula).
4. Verify BPM updates arrive in real time over the `heartrate-live` Pusher channel.

## Security & Configuration

- **Never commit:** Pusher secret, `GoogleService-Info.plist` (if Firebase is ever re-added), API keys.
- Pusher secret lives **only** in Vercel environment variables; clients receive the public key via `/api/config`.
- The public stream is world-readable: anyone who can reach the page can view the live BPM. Treat the deployed URL as a capability link.
- Server validates BPM range (20–300) before publishing to reject bogus values.

## Code Style

- `PascalCase` for types, `camelCase` for functions/properties
- Suffix manager/service classes with role: `HealthKitManager`, `PusherService`
- Web code: double-quoted HTML attributes, kebab-case CSS classes, minimal inline scripts
- Keep Pusher channel/event name strings (`heartrate-live`, `heartrate-update`) consistent across iOS, server, and web
