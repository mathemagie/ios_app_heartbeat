# Pusher + Vercel Setup Guide

This guide walks through wiring up real-time heart-rate streaming from the iOS
app to the web client using **Pusher Channels** with a **Vercel serverless
backend**. The Pusher secret lives only on the server.

## Architecture (one screen)

```
iOS app  ──HTTPS POST──►  Vercel /api/heartbeat  ──Pusher REST──►  Pusher
                                                                     │
                                                              WebSocket push
                                                                     ▼
                                                              Web nebula page
                                                              (subscribes to
                                                               heartrate-live)
```

- **Channel:** `heartrate-{shareId}` — public, currently always `heartrate-live`.
- **Event:** `heartrate-update` with payload `{bpm, timestamp, source, shareId}`.
- **Secret:** only in Vercel env vars. The web page calls `/api/config` to fetch
  the public key + cluster at runtime.

## Prerequisites

- Free Pusher account ([pusher.com](https://pusher.com))
- Vercel account + the Vercel CLI (the repo's `make install` installs it locally)
- Xcode 15+ for the iOS side
- Real iPhone with a heart-rate source (AirPods Pro 3 or Apple Watch) for live data

## Step 1 — Create a Pusher Channels app

1. Sign up at [pusher.com](https://pusher.com), click **Create app**, choose
   **Channels**.
2. Pick a cluster close to you (e.g. `eu`, `us2`, `ap1`).
3. From **App Keys**, note:
   - `app_id`
   - `key` (public, safe to expose)
   - `secret` (**server only**, never commit, never ship to clients)
   - `cluster`

Client events do **not** need to be enabled — all publishing is server-side via
the Pusher REST API.

## Step 2 — Configure Vercel env vars

In Vercel → your project → **Settings → Environment Variables**, add the four
keys for **Production** (and **Preview**/**Development** if you want
`vercel dev` to publish too):

| Name             | Value                       |
|------------------|-----------------------------|
| `PUSHER_APP_ID`  | from Pusher                 |
| `PUSHER_KEY`     | from Pusher (public)        |
| `PUSHER_SECRET`  | from Pusher (**secret**)    |
| `PUSHER_CLUSTER` | e.g. `eu`                   |

After setting them, redeploy (`make deploy`) so the functions pick them up.

To pull env vars locally for `vercel dev`:

```bash
npx vercel link        # one-time
npx vercel env pull    # writes .env.local
```

## Step 3 — Deploy or run locally

### Deploy to production

```bash
make install   # one-time: install the Vercel CLI
make deploy    # npx vercel --prod
```

The output prints your deployment URL (e.g. `https://your-app.vercel.app`).

### Run the full stack locally

```bash
make dev       # vercel dev on http://localhost:3000 (serves /api + /web)
```

Sanity check:

```bash
curl -s http://localhost:3000/api/config
# {"key":"…","cluster":"…"}

curl -s -X POST http://localhost:3000/api/heartbeat \
  -H 'Content-Type: application/json' \
  -d '{"shareId":"live","bpm":72,"timestamp":"2026-01-01T00:00:00Z","source":"curl"}'
# {"ok": true}
```

The POST should also appear in the Pusher dashboard **Debug Console** as a
`heartrate-update` event on the `heartrate-live` channel.

## Step 4 — Point the iOS app at your backend

Open `src/ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/PusherService.swift`.
The base URL is read from the `HEARTBEAT_API_BASE_URL` key in `Info.plist`,
falling back to a hard-coded default:

```swift
let configured = Bundle.main.object(forInfoDictionaryKey: "HEARTBEAT_API_BASE_URL") as? String
let urlString = (configured?.isEmpty == false ? configured! : "https://project-56opg.vercel.app")
```

Either:
- Add `HEARTBEAT_API_BASE_URL` to the target's `Info.plist`, set to your
  Vercel URL (`https://your-app.vercel.app`), **or**
- Edit the fallback string in `PusherService.swift` directly.

No Pusher SDK is required on iOS — the app just uses `URLSession` to POST JSON.

## Step 5 — Build and test

### iOS

```bash
make ios-open     # opens in Xcode
# ⌘R on a real iPhone, grant HealthKit permission, tap Start Monitoring
```

CLI alternatives:

```bash
make ios-build    # generic iOS device build
make ios-sim      # boots a simulator (UI/upload only; no real BPM)
```

Watch the Xcode console for `📤 Published heart rate: N BPM` lines.

### Web

- Production: visit your Vercel URL — `/` serves `src/web/index.html`.
- Local against `vercel dev`: `http://localhost:3000/index.html`.
- Local web-only (no API): `make web` → `http://localhost:8000/index.html`
  (will fail to fetch `/api/config` and fall back to a baked-in default key —
  prefer `make dev` for real testing).

Open the browser console; you should see `[heartrate-update] {bpm: …}` logs and
the nebula start breathing at the live BPM.

## Step 6 — Run the web helper tests

```bash
make test
# node --test "tests/**/*.test.js"
```

Covers the pure helpers in `src/web/nebula.js` (BPM clamping, period math, pulse
curve, validation).

## Troubleshooting

**`/api/heartbeat` returns 500 "server misconfigured: missing …":**
- One of the `PUSHER_*` env vars is unset in Vercel. Add it, then redeploy.

**`/api/heartbeat` returns 400 "invalid or missing shareId":**
- `shareId` must match `^[A-Za-z0-9]{4,32}$`. The default value `"live"`
  passes; custom IDs must too.

**`/api/heartbeat` returns 400 "bpm out of range (20-300)":**
- The server clamps to a sane physiological range. Send a value inside it.

**iOS app logs `⚠️ Upload HTTP 404`:**
- The base URL points somewhere without the API routes. Confirm
  `HEARTBEAT_API_BASE_URL` (or the fallback in `PusherService.swift`) is the
  Vercel deployment for *this* repo.

**Web page stays at `--`:**
- Browser console: did `/api/config` succeed? Did `Pusher` connect?
- Pusher **Debug Console**: are events showing up on `heartrate-live`?
- iOS app: is the streamer running and printing `📤 Published heart rate`?

**Rate limiting:**
- The iOS app caps publishes at one every 2 s. Don't expect more frequent
  updates regardless of how many HealthKit samples arrive.

## Cost & limits

Pusher's free tier offers 200k messages/day and 100 concurrent connections —
plenty for one or a few simultaneous viewers. See
[pusher.com/channels/pricing](https://pusher.com/channels/pricing) for paid
plans.

## Resources

- [Pusher Channels docs](https://pusher.com/docs/channels/)
- [Pusher Python server SDK](https://github.com/pusher/pusher-http-python)
- [Pusher JS client](https://pusher.com/docs/channels/getting_started/javascript/)
- [Vercel Python functions](https://vercel.com/docs/functions/runtimes/python)
- `PUSHER_ARCHITECTURE.md` — design notes on why the secret moved server-side
