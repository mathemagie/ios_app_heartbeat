# Pusher Integration Setup Guide

This guide walks through setting up Pusher Channels for real-time heart rate streaming from the iOS app to the web client.

## Overview

The app now uses Pusher Channels to broadcast heart rate data in real-time:
- **iOS App** → Publishes heart rate updates to Pusher channel `heartrate-{shareId}`
- **Web Client** → Subscribes to the same channel and displays live BPM updates

## Prerequisites

- Pusher account (free tier available at [pusher.com](https://pusher.com))
- Xcode 15+ for iOS development
- Modern web browser for testing the web client

## Step 1: Create a Pusher Account and App

1. **Sign up for Pusher**
   - Go to [pusher.com](https://pusher.com) and create a free account
   - The free tier includes 200k messages/day and 100 concurrent connections

2. **Create a new Channels app**
   - From the Pusher dashboard, click "Create app"
   - Choose "Channels" as the product
   - Name your app (e.g., "HeartBeatStream")
   - Select your cluster (e.g., `us2`, `eu`, `ap1`) - choose closest to your location
   - Choose "Create my app"

3. **Enable Client Events**
   - In your Pusher app dashboard, go to "App Settings"
   - Scroll down to "Client Events"
   - **Enable client events** (REQUIRED for the iOS app to publish directly)
   - Save changes

## Step 2: Get Your Pusher Credentials

From your Pusher app dashboard, go to "App Keys" and note:
- **app_id**: Your application ID
- **key**: Your public app key (safe to include in client code)
- **secret**: Your app secret (DO NOT commit to git)
- **cluster**: Your app cluster (e.g., `us2`, `eu`, `ap1`)

## Step 3: Add Pusher SDK to iOS Project

### 3.1 Add Pusher Package via Xcode

1. **Open the Xcode project:**
   ```bash
   xed ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj
   ```

2. **Add Swift Package:**
   - In Xcode, go to `File` → `Add Package Dependencies...`
   - Enter the package URL: `https://github.com/pusher/pusher-websocket-swift.git`
   - Select version: `10.1.9` or "Up to Next Major Version from 10.1.9"
   - Click "Add Package"
   - Select "PusherSwift" library and click "Add Package"

3. **Verify the package was added:**
   - In the Project Navigator, you should see "PusherSwift" under "Package Dependencies"

### 3.2 Configure PusherService with Your Credentials

1. **Open PusherService.swift:**
   ```bash
   open ios/HeartBeatStream/HeartBeatStream/HeartBeatStream/PusherService.swift
   ```

2. **Update the credentials** (around lines 8-9):
   ```swift
   private let pusherKey = "YOUR_PUSHER_APP_KEY"        // Replace with your key
   private let pusherCluster = "YOUR_PUSHER_CLUSTER"    // e.g., "us2", "eu", "ap1"
   ```

3. **Important Security Note:**
   - The `pusherKey` is your **public key** - it's safe to include in the app
   - Never include your Pusher **secret** in client-side code
   - Client events must be enabled in Pusher dashboard for the app to publish

## Step 4: Configure Web Client

1. **Open web/index.html:**
   ```bash
   open web/index.html
   ```

2. **Update Pusher credentials** (around lines 78-79):
   ```javascript
   const PUSHER_KEY = 'YOUR_PUSHER_APP_KEY'        // Same key as iOS app
   const PUSHER_CLUSTER = 'YOUR_PUSHER_CLUSTER'    // Same cluster as iOS app
   ```

## Step 5: Build and Test

### 5.1 Test the iOS App

1. **Build and run on a real iPhone:**
   ```bash
   xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build
   ```
   Or run directly from Xcode (⌘R) on a physical device

2. **Grant HealthKit permission** when prompted

3. **Tap "Start Monitoring"**
   - You should see "Pusher: connected" in the UI
   - The app will display your current heart rate
   - Note the **Share ID** displayed in the app (e.g., `a1b2c3d4`)

4. **Check Pusher Dashboard:**
   - Go to your Pusher app → "Debug Console"
   - You should see connection events and messages when heart rate updates

### 5.2 Test the Web Client

1. **Serve the web client:**
   ```bash
   python3 -m http.server --directory web 8000
   ```

2. **Open in browser** with your Share ID:
   ```
   http://localhost:8000/index.html?share=YOUR_SHARE_ID
   ```
   Replace `YOUR_SHARE_ID` with the Share ID from the iOS app

3. **Verify real-time updates:**
   - You should see "connected" status in the web UI
   - Heart rate should update in real-time as data comes from the iOS app
   - Updates should appear within 1-2 seconds

## Architecture Details

### How It Works

1. **iOS App (Publisher):**
   - Connects to Pusher using WebSocket
   - Subscribes to channel: `heartrate-{shareId}`
   - Publishes client events: `client-heartrate-update` with BPM data
   - Channel is created automatically when first client connects

2. **Web Client (Subscriber):**
   - Connects to Pusher using JavaScript SDK
   - Subscribes to same channel: `heartrate-{shareId}`
   - Listens for `client-heartrate-update` events
   - Updates DOM with received heart rate data

3. **Pusher Channels:**
   - Maintains WebSocket connections to both iOS and web clients
   - Routes messages from iOS app to web client(s) in real-time
   - No server-side code needed for this use case

### Data Flow

```
HealthKit → HealthKitManager → HeartRateStreamer → PusherService
                                                         ↓
                                                    Pusher Channels
                                                         ↓
                                                    Web Client
```

### Channel Naming

- Format: `heartrate-{shareId}`
- Example: `heartrate-a1b2c3d4`
- Each user gets a unique channel based on their Share ID
- Share ID is generated once and persisted in UserDefaults

## Troubleshooting

### iOS App Issues

**Pusher shows "disconnected" or "failed":**
- Check that you entered the correct `pusherKey` and `pusherCluster` in `PusherService.swift`
- Verify client events are enabled in Pusher dashboard
- Check internet connection on the device
- Review Xcode console for error messages

**Build errors about missing PusherSwift:**
- Ensure you added the package via Xcode (see Step 3.1)
- Try `Product` → `Clean Build Folder` (Shift+⌘+K)
- Restart Xcode and rebuild

### Web Client Issues

**"Waiting for data..." never changes:**
- Check browser console (F12) for errors
- Verify `PUSHER_KEY` and `PUSHER_CLUSTER` match your Pusher app settings
- Ensure Share ID in URL matches the one shown in iOS app
- Check that iOS app is running and connected to Pusher

**"Failed to subscribe to channel" error:**
- Verify client events are enabled in Pusher dashboard
- Check that the channel name format is correct: `heartrate-{shareId}`
- Review Pusher dashboard Debug Console for subscription errors

### General Issues

**No data flowing from iOS to web:**
- Verify both iOS app and web client show "connected" status
- Check Pusher Debug Console for published events
- Ensure the iOS device has heart rate data (from Apple Watch or other source)
- Try starting monitoring on iOS app, then opening web client

**Data delayed or missing:**
- Pusher typically delivers messages in <100ms
- iOS background delivery may be deferred by the system
- Keep iOS app in foreground for testing
- Check Pusher plan limits (free tier has rate limits)

## Security Considerations

### Public Channels (Current Implementation)

- Channels are **public by default** - anyone with the Share ID can view
- Share ID acts as a "secret" URL parameter
- Suitable for personal use or sharing with trusted people

### Private/Encrypted Channels (Advanced)

For production use with sensitive data, consider:

1. **Private Channels:**
   - Require authentication endpoint on your server
   - Verify user permissions before allowing subscription
   - Change channel name to `private-heartrate-{shareId}`

2. **Encrypted Channels:**
   - End-to-end encryption of message payloads
   - Requires server-side implementation
   - Change channel name to `private-encrypted-heartrate-{shareId}`

3. **Best Practices:**
   - Rotate Share IDs regularly (delete and reinstall app)
   - Don't share Share IDs publicly
   - Monitor Pusher dashboard for unexpected connections
   - Consider adding user authentication in the future

## Cost & Limits

### Pusher Free Tier

- **200,000 messages/day**
- **100 max connections**
- **Unlimited channels**

For this app:
- 1 heart rate update = 1 message
- Typical heart rate: 60-100 BPM = 1 update per sample
- If publishing every 5 seconds = ~17,280 messages/day per user
- Free tier supports ~11 concurrent active users streaming all day

### Paid Plans

If you exceed free tier limits:
- **Starter**: $29/month (500k messages/day)
- **Professional**: $99/month (2M messages/day)
- See [pusher.com/pricing](https://pusher.com/channels/pricing) for details

## Next Steps

- **Add authentication:** Implement private channels with server-side auth
- **Add history:** Store heart rate data in a database for trends/charts
- **Multiple viewers:** Share the same Share ID with multiple web clients
- **Mobile web:** Make the web UI responsive for mobile viewing
- **Notifications:** Add alerts when heart rate exceeds thresholds

## Resources

- [Pusher Channels Documentation](https://pusher.com/docs/channels/)
- [Pusher iOS Quick Start](https://pusher.com/docs/channels/getting_started/ios/)
- [pusher-websocket-swift GitHub](https://github.com/pusher/pusher-websocket-swift)
- [Pusher JavaScript Client](https://pusher.com/docs/channels/getting_started/javascript/)
- [Client Events Documentation](https://pusher.com/docs/channels/using_channels/events/#triggering-client-events)
