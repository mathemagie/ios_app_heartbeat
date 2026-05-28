# Pusher Channels — Architecture Options & the Secret Problem

This doc captures the design decision behind the current architecture: why the
Pusher secret was moved off the clients and onto a Vercel serverless backend.
The repo now implements **Option B** below; the "previous setup" section is
kept as historical context.

> **Status: Option B is implemented.** iOS POSTs to `/api/heartbeat` on Vercel;
> the function publishes to a **public** channel `heartrate-{shareId}` using
> the Pusher REST API. The secret lives only in Vercel env vars. The web page
> subscribes with the public key (fetched from `/api/config`) — no browser
> HMAC, no `crypto.subtle`, no auth.

## Previous setup (insecure — no longer used)

- **iOS** used to publish via a **client event**:
  `channel.trigger("client-heartrate-update", …)` on the **private** channel
  `private-heartrate-{shareId}` (via the PusherSwift SDK).
- **Web** subscribed to the same private channel and signed the auth in the
  browser using HMAC-SHA256.
- The **Pusher secret was hardcoded in both clients**.

### Why that was a problem
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
| **Previous:** private + client events | needs auth (secret in client) | iOS directly | ❌ in clients (insecure) | ✅ required | No |
| **A:** private + server auth endpoint | server signs auth | iOS directly (client events) | ✅ server only | ✅ still required | Yes (auth only) |
| **B (current):** public channel + server publishes | none | **server** (iOS POSTs BPM to it) | ✅ server only | ❌ not needed | Yes (auth + publish) |

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

## Option B — Public channel + server publishes (implemented)

This is what the repo does today. The Vercel function in `api/heartbeat.py` is
the server; `api/config.py` exposes the public key to the web page. iOS no
longer talks to Pusher directly. The flow:

1. **iOS** sends each BPM to your server: `POST /heartbeat` with `{ shareId, bpm, … }`.
2. **Server** uses the Pusher **REST API** (server SDK, secret server-side) to
   `trigger` event `heartrate-update` on the **public** channel `heartrate-{shareId}`.
3. **Web** subscribes to the public channel `heartrate-{shareId}` — **no auth, no
   `crypto.subtle`, no secret.** The original browser error disappears entirely.

- **Pros:** secret only on server; simplest, safest web client; fixes the secure-context
  error; can add validation/rate-limiting/persistence server-side.
- **Cons:** iOS no longer talks to Pusher directly (it talks to your server); you must
  deploy and run a server.

### Actual server (Vercel Python — see `api/heartbeat.py`)
```python
import os, pusher
client = pusher.Pusher(
    app_id=os.environ["PUSHER_APP_ID"],
    key=os.environ["PUSHER_KEY"],
    secret=os.environ["PUSHER_SECRET"],   # server-only
    cluster=os.environ["PUSHER_CLUSTER"],
    ssl=True,
)
# In the POST handler, after validating shareId (^[A-Za-z0-9]{4,32}$)
# and bpm (20–300):
client.trigger(
    f"heartrate-{share_id}",
    "heartrate-update",
    {"bpm": bpm, "timestamp": timestamp, "source": source, "shareId": share_id},
)
```
Web side becomes just:
```js
const pusher = new Pusher(PUSHER_KEY, { cluster: "eu" }); // key only, no secret
const channel = pusher.subscribe(`heartrate-${shareId}`);  // public, no auth
channel.bind("heartrate-update", (data) => { /* update UI */ });
```

## One-time action when migrating from the old setup

- **Rotate the Pusher secret** (Pusher dashboard → App Keys → roll secret).
  The previous secret was exposed in client binaries and git history.
- Set the new `PUSHER_APP_ID` / `PUSHER_KEY` / `PUSHER_SECRET` /
  `PUSHER_CLUSTER` as Vercel env vars; never commit them.
- Remove any baked-in secret/key strings from `PusherService.swift` and
  `web/index.html` (already done in this repo).

## Outcome

Option B is now live: the secret is server-only, the web client uses no
browser crypto, and the API gives a natural place to enforce validation
(BPM range, `shareId` shape) and could later host persistence or rate limiting.
The cost is a single tiny Vercel function per request.

Sources:
- Pusher — What is an event? (client-event restrictions): https://pusher.com/docs/channels/using_channels/events/
- Pusher — Private channels: https://pusher.com/docs/channels/using_channels/private-channels/
