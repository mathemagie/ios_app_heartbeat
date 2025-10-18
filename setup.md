• Setup Essentials

  - Install Xcode from the Mac App Store; it bundles the iOS SDK, Simulator,
    Interface Builder, and compilers. After installation, open Xcode once so it
    finishes installing command-line components.
  - Run xcode-select --install in Terminal to ensure the Xcode Command Line Tools
    are available for scripts such as xcodebuild.
  - Sign in to Xcode with your Apple ID. A free account is enough for simulator
    runs; streaming heart rate from HealthKit requires an Apple Developer account
    and a provisioning profile tied to a physical device.

  Project-Specific Extras

  - Add the Firebase iOS SDK via Swift Package Manager inside Xcode if it isn’t
    already resolved; speeding this up can require one-time trust of the GitHub
    host.
  - Download your project’s GoogleService-Info.plist from Firebase and add it to
    the HeartBeatStream target; without it Firebase won’t configure.
  - Install the Firebase CLI (npm install -g firebase-tools) if you plan to deploy
    database rules or test the web client locally.
  - For real-device HealthKit testing, plug in an iPhone, enable developer mode,
    and make sure Health permissions are granted inside the app; the simulator
    lacks real heart-rate data.

  Next steps: once Xcode and the plist are in place, open ios/HeartBeatStream/
  HeartBeatStream.xcodeproj, select an iPhone device, and build/run.
