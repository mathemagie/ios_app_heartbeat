# Repository Guidelines

## Project Structure & Module Organization
- `ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/` — SwiftUI app sources. Keep HealthKit work in `HealthKitManager.swift`, coordination in `HeartRateStreamer.swift`, and network publishing in `PusherService.swift` (which POSTs to the Vercel API — there is no client-side Pusher SDK and no Firebase).
- `api/` — Vercel serverless Python functions: `heartbeat.py` (POST `/api/heartbeat` → Pusher REST `trigger`) and `config.py` (GET `/api/config` → public `{key, cluster}`).
- `web/` — vanilla-JS clients. `index.html` is the live "nebula" visualization; `nebula.js` holds the pure helpers shared with tests.
- `test/nebula.test.js` — Node built-in test runner suite for the web helpers.
- `scripts/run-simulator.sh` — boots, installs, and launches the app on a chosen iOS simulator.
- `Makefile` — common commands; run `make help` to list targets.

## Build, Test, and Development Commands
- `make ios-open` (or `xed ios/HeartBeatStream`) — open the app in Xcode.
- `make ios-build` — `xcodebuild` for a generic iOS device.
- `make ios-sim DEVICE="iPhone 16"` — build, install, and launch on the simulator (UI/Pusher only; no real BPM).
- `make web` — serve `web/` at `http://localhost:8000/index.html`.
- `make dev` — run the full stack locally with `vercel dev` on port 3000 (serves `api/` + `web/`).
- `make test` — run the Node test suite (`node --test "test/**/*.test.js"`).
- `make deploy` — `npx vercel --prod`. Releases are manual; `git push` does not deploy.

## Coding Style & Naming Conventions
- Swift: 4-space indentation, `final` classes unless subclassing is needed, protocol-oriented seams where it helps testability. `PascalCase` for types, `camelCase` for functions/properties; suffix service/manager classes with their role (`HealthKitManager`, `PusherService`).
- Python (`api/`): standard library only where possible (`pusher` is the one runtime dep, per `requirements.txt`). Validate every field coming from the network; never log the Pusher secret.
- Web: dependency-free vanilla JS. Double-quoted HTML attributes, kebab-case CSS classes, small inline scripts. Keep pure helpers in `web/nebula.js` so they remain testable from Node.
- Keep the Pusher channel/event names (`heartrate-{shareId}` / `heartrate-update`) consistent across iOS, server, and web.

## Testing Guidelines
- **Web helpers:** `make test` (or `node --test "test/**/*.test.js"`). Add new pure helpers to `web/nebula.js` and cover them in `test/nebula.test.js`.
- **End-to-end on device:** run the app on a real iPhone with a paired heart-rate source (AirPods Pro 3 or Apple Watch), then open the deployed nebula page and confirm BPM updates within 1–2 seconds.
- **API:** with `make dev` running, `curl -s http://localhost:3000/api/config` should return the public key/cluster, and a `POST /api/heartbeat` with `{shareId,bpm,timestamp,source}` should return `{"ok": true}` and surface in the Pusher Debug Console.

## Commit & Pull Request Guidelines
- Imperative, scope-prefixed commit subjects (e.g., `ios: switch publish path to /api/heartbeat`, `web: simplify nebula pulse`).
- PRs should summarize behaviour changes, list validation steps (commands run, devices used), and link any related issue/TODO.
- Call out changes that touch the publish contract (shareId format, channel/event names, BPM range) or the API surface — both iOS and web must stay in sync.

## Security & Configuration Tips
- **Never commit the Pusher secret.** It lives only as a Vercel env var (`PUSHER_SECRET`, plus `PUSHER_APP_ID` / `PUSHER_KEY` / `PUSHER_CLUSTER`). Clients only ever see the public key via `/api/config`.
- The Pusher channel is **public**: anyone with the URL can view the live BPM. Treat the deployed page as a capability link.
- The server clamps BPM to 20–300 and validates `shareId` against `^[A-Za-z0-9]{4,32}$` — preserve those guards when editing `api/heartbeat.py`.
