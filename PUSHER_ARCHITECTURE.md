# Pusher Channels — Architecture Options & the Secret Problem

This doc explains how heart-rate data flows through Pusher today, why the current
setup is insecure, and the realistic ways to fix it. No code has been changed by
this document — it's a decision aid.

## Current setup (insecure)

- **iOS** publishes via a **client event**: `channel.trigger("client-heartrate-update", …)`
  on the **private** channel `private-heartrate-{shareId}`
  (`ios/.../PusherService.swift`).
- **Web** subscribes to the same private channel and signs the auth in the browser
  using HMAC-SHA256 (`web/index.html`).
- The **Pusher secret is hardcoded in both clients** (`PusherService.swift` and
  `index.html`).

### Why this is a problem
1. **The secret is public.** Anyone who reads the iOS binary or views the web page
   source gets the secret and can forge auth for any channel, impersonate users,
   and call Pusher's server API. The secret is also now in git history → **rotate it.**
2. **`crypto.subtle` requires a secure context.** Browser HMAC signing only works on
   `https://` or `http://localhost`. Plain-HTTP LAN/`file://` access throws
   `Cannot read properties of undefined (reading 'importKey')`.

## Key Pusher constraint

> Client events can only be triggered on **private and presence channels** — **not
> public channels.** They require an authorized subscription.
> — https://pusher.com/docs/channels/using_channels/events/

**Consequence:** a client (iOS) can only *publish* on a **private/presence** channel,
which requires auth, which requires the secret. **Public** channels need no auth to
subscribe, but events can only be published to them **server-side via the Pusher REST
API** (using the secret on a server).

→ There is **no way** to both (a) publish directly from the iOS client and
(b) keep the secret off all clients **without a server**.

## Option comparison

| | Subscriber auth | Who publishes | Secret location | Web `crypto.subtle`? | Server needed? |
|---|---|---|---|---|---|
| **Current:** private + client events | needs auth (secret in client) | iOS directly | ❌ in clients (insecure) | ✅ required | No |
| **A:** private + server auth endpoint | server signs auth | iOS directly (client events) | ✅ server only | ✅ still required | Yes (auth only) |
| **B:** public channel + server publishes | none | **server** (iOS POSTs BPM to it) | ❌ not needed | ❌ not needed | Yes (auth + publish) |

## Option A — Private channel + server-side auth endpoint

Keep iOS publishing client events on the private channel, but move auth signing to a
small server endpoint that holds the secret.

- **Server:** `POST /pusher/auth` → validates, returns the signed auth using the
  Pusher server SDK. (Pusher SDKs do this for you.)
- **iOS & web:** point their `authMethod` / `authorizer` at that endpoint instead of
  using an inline secret.
- **Pros:** smallest change to data flow; iOS keeps publishing directly.
- **Cons:** web still needs `crypto.subtle`? No — the **server** signs, so the browser
  no longer does HMAC; that removes the crypto error too. But you must keep "client
  events" enabled and a private subscription working. Still need a deployed server.

## Option B — Public channel + server publishes (recommended)

iOS stops publishing directly. Instead:

1. **iOS** sends each BPM to your server: `POST /heartbeat` with `{ shareId, bpm, … }`.
2. **Server** uses the Pusher **REST API** (server SDK, secret server-side) to
   `trigger` event `heartrate-update` on the **public** channel `heartrate-{shareId}`.
3. **Web** subscribes to the public channel `heartrate-{shareId}` — **no auth, no
   `crypto.subtle`, no secret.** The original browser error disappears entirely.

- **Pros:** secret only on server; simplest, safest web client; fixes the secure-context
  error; can add validation/rate-limiting/persistence server-side.
- **Cons:** iOS no longer talks to Pusher directly (it talks to your server); you must
  deploy and run a server.

### Sketch of the server (Node example, illustrative)
```js
import Pusher from "pusher";
const pusher = new Pusher({
  appId: process.env.PUSHER_APP_ID,
  key: process.env.PUSHER_KEY,
  secret: process.env.PUSHER_SECRET, // server-only
  cluster: "eu",
});
app.post("/heartbeat", (req, res) => {
  const { shareId, bpm, timestamp, source } = req.body;
  pusher.trigger(`heartrate-${shareId}`, "heartrate-update", { bpm, timestamp, source, shareId });
  res.sendStatus(204);
});
```
Web side becomes just:
```js
const pusher = new Pusher(PUSHER_KEY, { cluster: "eu" }); // key only, no secret
const channel = pusher.subscribe(`heartrate-${shareId}`);  // public, no auth
channel.bind("heartrate-update", (data) => { /* update UI */ });
```

## Immediate action regardless of option

- **Rotate the Pusher secret now** (App Keys → roll secret). The current one is
  exposed in clients and git history.
- Never commit secrets; load them from env vars on the server.

## Recommendation

**Option B** for a shareable heart-rate stream: it removes the secret from all
clients, eliminates the browser crypto requirement (and the `importKey` error), and
gives you a place to add validation/persistence. The cost is running a small server
and routing iOS publishes through it.

Sources:
- Pusher — What is an event? (client-event restrictions): https://pusher.com/docs/channels/using_channels/events/
- Pusher — Private channels: https://pusher.com/docs/channels/using_channels/private-channels/
