# HeartBeatStream

Stream your heart rate live from an iPhone to the web. The iOS app reads heart
rate samples from Apple Health via HealthKit, POSTs them to a tiny Vercel
serverless function, which publishes them to a public [Pusher
Channels](https://pusher.com) stream. A vanilla-JS "nebula" page subscribes and
breathes in sync with the beat.

```
AirPods/Watch → HealthKit → iOS app
                              │  HTTPS POST /api/heartbeat
                              ▼
                       Vercel serverless ── Pusher REST ──► Pusher Channels
                       (holds the secret)                          │
                                                                   ▼  WebSocket
                                                             Web nebula page
```

The Pusher **secret never ships to clients** — only the public key, fetched at
runtime from `/api/config`.

## Project Layout

- `src/ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/` — SwiftUI app
  - `HealthKitManager.swift` — HealthKit authorization and heart rate observation
  - `HeartRateStreamer.swift` — coordinates HealthKit data flow to UI and Pusher
  - `PusherService.swift` — POSTs BPM updates to `/api/heartbeat`
  - `ContentView.swift` — main UI (current BPM, status, source); hard-codes `shareId = "live"`
  - `AppDelegate.swift` — app entry point
- `src/api/heartbeat.py` — Vercel function: validates input, triggers Pusher event
- `src/api/config.py` — Vercel function: returns the public Pusher `{key, cluster}`
- `src/web/index.html` — Heart Nebula visualization (subscribes to `heartrate-live`)
- `src/web/architecture.html` — design/architecture explainer page
- `src/web/nebula.js` — pure, DOM-free helpers shared by the page and tests
- `tests/nebula.test.js` — Node built-in test runner suite
- `pages_index/index.html` — Heart Nebula explainer published via GitHub Pages
  at [mathemagie.github.io/nebula](https://mathemagie.github.io/nebula/)
- `.github/workflows/pages.yml` — GitHub Actions workflow that deploys
  `pages_index/` to GitHub Pages on every push that touches it
- `PUSHER_SETUP.md` — full Pusher + Vercel setup walkthrough
- `PUSHER_ARCHITECTURE.md` — design notes on why the secret moved server-side

## How It Works

1. **iOS app** requests HealthKit read access, observes new heart-rate samples
   with `HKObserverQuery` + `HKAnchoredObjectQuery`, and POSTs each reading to
   `https://<your-vercel-app>/api/heartbeat` as JSON.
2. **Vercel function (`src/api/heartbeat.py`)** validates the payload (BPM in
   20–300, `shareId` matching `^[A-Za-z0-9]{4,32}$`), then calls the Pusher
   REST API to publish event `heartrate-update` on the **public** channel
   `heartrate-{shareId}` (currently always `heartrate-live`).
3. **Web client** fetches `/api/config` for the public key/cluster, subscribes
   to `heartrate-live`, and updates the nebula on every event. Setting CSS
   `animation-duration = 60/bpm` makes the visuals beat at the real heart rate.

## Prerequisites

- **Xcode 15+**
- A **real iPhone** with a heart-rate source — AirPods Pro 3 in-ear PPG, or a
  paired Apple Watch. The Simulator has no heart-rate sensor.
- A free **Pusher account** ([pusher.com](https://pusher.com))
- A **Vercel account** + the Vercel CLI (`make install` installs it locally)

## Setup

### 1. Create a Pusher app

1. Sign up at [pusher.com](https://pusher.com) and **Create app** → Channels.
2. Pick a cluster (e.g. `eu`).
3. From **App Keys**, copy `app_id`, `key`, `secret`, and `cluster`. Client
   events do **not** need to be enabled — publishing is server-side.

### 2. Configure Vercel env vars

In Vercel → your project → **Settings → Environment Variables**, set:

| Name | Value |
|---|---|
| `PUSHER_APP_ID` | from Pusher dashboard |
| `PUSHER_KEY` | from Pusher dashboard (public) |
| `PUSHER_SECRET` | from Pusher dashboard (**server only**) |
| `PUSHER_CLUSTER` | e.g. `eu` |

### 3. Deploy or run locally

- **Deploy:** `make deploy` (runs `npx vercel --prod`). Note the deployment URL.
- **Run locally:** `make dev` starts `vercel dev` on `http://localhost:3000`,
  serving both `src/api/` and `src/web/`.

### 4. Point the iOS app at your Vercel URL

`PusherService.swift` defaults to a baked-in URL. Override it by adding a
`HEARTBEAT_API_BASE_URL` key to the app's `Info.plist`, or edit the default in
`init(...)`.

### 5. Build the iOS app

- From Xcode: `make ios-open`, then ⌘R on a real iPhone (grant HealthKit
  permission, tap **Start Monitoring**).
- From the CLI: `make ios-build` (device) or `make ios-sim` (simulator — UI
  only, no real BPM).

### 6. Open the web client

- Production: visit your Vercel URL.
- Local: `make web` then open `http://localhost:8000/index.html`.

The page beats in sync with the streamed BPM. A synthesized lub-dub heartbeat
sound can be toggled on.

## Common commands

```bash
make help        # list all targets
make dev         # full stack locally (vercel dev on :3000)
make web         # web only (python http.server on :8000)
make ios-sim     # build/install/launch on the iOS Simulator
make test        # node --test "tests/**/*.test.js"
make deploy      # npx vercel --prod
```

## Security & Privacy

- The Pusher **secret lives only as a Vercel env var**; the client only sees
  the public key via `/api/config`.
- The Pusher channel is **public** — anyone who can reach the deployed URL can
  view the live BPM. Treat the URL as a capability link.
- The server validates BPM (20–300) and `shareId` (`^[A-Za-z0-9]{4,32}$`)
  before publishing.
- Heart-rate data is only read from HealthKit with explicit user permission.

## Troubleshooting

**No BPM in the iOS UI:**
- Run on a real iPhone (the Simulator has no heart-rate sensor).
- Verify the Health app has recent heart-rate samples and that HeartBeatStream
  has read permission (Settings → Privacy & Security → Health).

**iOS shows "error" / no upload:**
- Confirm `HEARTBEAT_API_BASE_URL` (or the baked-in default in
  `PusherService.swift`) points to a reachable Vercel deployment.
- `curl -s <base>/api/config` should return `{"key":"…","cluster":"…"}`.

**Web page stays at `--`:**
- Open the browser console; check `/api/config` succeeded and that you're
  subscribed to `heartrate-live`.
- In the Pusher dashboard **Debug Console**, look for `heartrate-update`
  events on the `heartrate-live` channel.
- Confirm the iOS app is running and publishing (logs print `📤 Published
  heart rate: N BPM`).

See `PUSHER_SETUP.md` for the longer walkthrough and `PUSHER_ARCHITECTURE.md`
for why the secret moved server-side.
