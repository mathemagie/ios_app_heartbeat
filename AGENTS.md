# Repository Guidelines

## Project Structure & Module Organization
- `ios/HeartBeatStream/` contains the SwiftUI app sources; keep HealthKit logic in `HealthKitManager.swift` and Firebase writes in `FirebaseService.swift`.
- `web/index.html` is the lightweight listener UI; colocate any static assets here.
- `firebase/database.rules.json` stores Realtime Database rules, and `plan.md` captures current architecture decisions—update both when schema or flows change.

## Build, Test, and Development Commands
- `xed ios/HeartBeatStream` opens the app sources in Xcode (target name: `HeartBeatStream`).
- `xcodebuild -scheme HeartBeatStream -destination 'generic/platform=iOS' build` runs a CLI build; adjust the scheme if you rename the target.
- `firebase deploy --only database` publishes rule updates after running `firebase login` once per machine.
- `python3 -m http.server --directory web 8000` serves the web demo at `http://localhost:8000/index.html?share=YOUR_ID` for quick manual checks.

## Coding Style & Naming Conventions
- Swift code uses 4-space indentation, `final` classes when subclassing is unnecessary, and protocol-oriented seams for testability.
- Apply `PascalCase` to types and `camelCase` to functions/properties; suffix helpers with meaningful roles (`HealthKitManager`, `FirebaseService`).
- Re-indent with Xcode or run `swiftformat` if available before committing, and centralize Firebase path strings in helper methods.
- Web markup stays dependency-free: double-quoted attributes, kebab-case CSS classes, and inline scripts kept small.

## Testing Guidelines
- Perform device runs: stream heart rate, then confirm data under `users/{uid}` and `publicStreams/{shareId}` in the Firebase console.
- House future unit/UI tests under `ios/HeartBeatStreamTests/`; execute them with `xcodebuild -scheme HeartBeatStream -destination 'platform=iOS Simulator,name=iPhone 15' test`.
- Validate the web client by observing DOM updates while pushing sample documents via the app or Firebase console.

## Commit & Pull Request Guidelines
- Use imperative, scope-prefixed commit subjects where helpful (e.g., `ios: wire HealthKit observer`).
- PR descriptions should summarize behaviour changes, list validation steps, and link issues or TODO checkboxes you addressed.
- Explicitly mention Firebase rule modifications and confirm `firebase deploy --only database` ran in the PR body.
- Keep diffs focused and call out any impacts to sharing identifiers, auth, or privacy expectations during review.

## Security & Configuration Tips
- Exclude `GoogleService-Info.plist` and other credentials from the repo; share setup steps securely in PRs or docs.
- Revisit `firebase/database.rules.json` whenever you extend the schema to ensure private paths stay auth-restricted.
- Treat generated share IDs as sensitive handles; document length or generation changes so clients and rules remain aligned.
