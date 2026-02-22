# Take Care App — Tests

## Xcode setup

1. Add a **Unit Test** target: File → New → Target → **Unit Testing Bundle**. Name it `TakeCareAppTests`.
2. Set the test target’s **Host Application** to the iOS app target (e.g. `TakeCareApp`).
3. Add the test files in `TakeCareAppTests/` to the `TakeCareAppTests` target:
   - `PacingEngineTests.swift`
   - `SessionRepositoryTests.swift`
   - `SyncPayloadsTests.swift`
4. Ensure the test target links the app (or a shared framework that contains Shared code). The app target must expose the code under test; use **@testable import TakeCareApp** (match the app target’s **Product Module Name**).

## Test classes

- **PacingEngineTests**: Rolling-window helpers, sensitivity presets, pacing rules (2 shots → warning, 4 units/90 min → escalation, hydration cadence, cooldown).
- **SessionRepositoryTests**: Session auto-end after timeout, endedSessions excludes active sessions (uses in-memory SwiftData).
- **SyncPayloadsTests**: Session, log, and endSession payload encode/decode round-trips.

Run tests with **Cmd+U** or the Test navigator.
