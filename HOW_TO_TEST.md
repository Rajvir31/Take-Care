# How to Test the Take Care App

This guide covers unit tests, running the apps in the simulator or on device, and manual test scenarios (including Watch ↔ iPhone sync).

---

## 1. Prerequisites

- **Xcode 16+** (for iOS 18 / watchOS 11).
- The project must be opened as an **Xcode project**. If you only have the folder of Swift files:
  - Create a new **iOS App** (e.g. product name **TakeCareApp**).
  - Add a **Watch App** target (iOS App with Watch App, or add Watch App for Existing Application).
  - Add all **Shared**, **WatchApp**, **TakeCareWatchApp**, and **iPhoneApp** (and **TakeCareApp**) source files to the correct targets (see PROJECT_STRUCTURE.md).
  - Set **iOS Deployment Target** to **18.0** and **watchOS** to **11.0**.

---

## 2. Unit Tests

### Setup the test target (one-time)

1. **File → New → Target → Unit Testing Bundle**. Name it **TakeCareAppTests**.
2. Set **Host Application** to your **iOS app target** (e.g. **TakeCareApp**).
3. Add the test files to the **TakeCareAppTests** target:
   - `Tests/TakeCareAppTests/PacingEngineTests.swift`
   - `Tests/TakeCareAppTests/SessionRepositoryTests.swift`
   - `Tests/TakeCareAppTests/SyncPayloadsTests.swift`
4. Ensure the test target’s **Product Module Name** matches what you use in the app (e.g. **TakeCareApp**). The tests use **@testable import TakeCareApp**; if your app target has a different module name, change the import in the test files.

### Run unit tests

- **Cmd+U** — run all tests for the current scheme.
- Or open the **Test navigator** (Cmd+6), select **TakeCareAppTests**, and click the run button next to the suite or a single test.

You should see:

- **PacingEngineTests**: Rolling-window counts, 2 shots → warning, 4 units/90 min → escalation, hydration every 2 drinks, cooldown, sensitivity, good pace with no logs.
- **SessionRepositoryTests**: Auto-end after timeout, no auto-end within timeout, endedSessions excludes active session.
- **SyncPayloadsTests**: Session, log, and endSession payload round-trips.

---

## 3. Running the iOS App (iPhone)

1. Select the **TakeCareApp** (or your iOS app) scheme.
2. Choose **iPhone 16** (or any iOS 18+) simulator, or a connected iPhone.
3. **Run** (Cmd+R).

**Quick manual check:**

- **Tonight**: Start session → log a few drinks (Shot, Beer, etc.) → see session summary and pace; try Undo; End session.
- **History**: After ending a session, open History → tap a session → check summary and timeline.
- **Insights**: After at least one ended session, open Insights → check charts and stats.
- **Settings**: Open and confirm disclaimer / placeholder items.

---

## 4. Running the Watch App

1. Select the **TakeCareWatchApp** (or your watch app) scheme.
2. Choose a **watchOS** simulator (e.g. **Apple Watch Series 10 – 46mm**) or a **paired** simulator (e.g. **Apple Watch Series 10** with **iPhone 16**).
3. **Run** (Cmd+R).

**Quick manual check:**

- Start Session → log drinks (Shot, Beer, Wine, Water, etc.) → confirm haptics and session summary (drink count, pace badge, “Last: Xm ago”).
- Undo Last → last drink removed.
- End Session → session cleared.

---

## 5. Testing Watch ↔ iPhone Sync

WatchConnectivity only works when the watch and phone are **paired**:

- **Real devices**: iPhone and Apple Watch paired via the Watch app.
- **Simulators**: Use the **iPhone + Apple Watch** simulator pair (e.g. “iPhone 16” and “Apple Watch Series 10” with the pairing option). Run the **iPhone app** first, then the **watch app** (or run the watch app and ensure the paired iPhone simulator is “on”).

### Sync: Watch → Phone

1. On the **watch**: Start a session and log several drinks (e.g. Beer, Shot, Wine).
2. On the **iPhone**: Open the app (Tonight tab). You should see the **same session** and **same logs** (and same drink count) once sync has run.
3. Open **History** on the phone and **End session** on the watch. After a moment, the session on the phone should show as ended and appear in History.

If the phone is in the background or the watch is unreachable, the watch uses **transferUserInfo**; the phone applies the payloads when it runs or becomes active.

### Sync: Phone → Watch

1. On the **iPhone**: Open **Settings** (when implemented, change e.g. sensitivity or hydration cadence and save).
2. On the **watch**: Open the app (or bring it to foreground). The watch receives **application context** (settings) and/or **userInfo** (drink types). Pacing and drink-type defaults should match the phone.

Currently the phone pushes settings on **appear** and **willEnterForeground** in **MainTabView**, so opening the iPhone app (or switching back to it) triggers a push to the watch.

### Things that can go wrong

- **No sync**: Pairing not set up, or wrong scheme (e.g. running only the watch app without the paired iPhone simulator). Check that both apps have been run and that WCSession is activated.
- **Duplicate logs**: The phone dedupes by log **id**; if you see duplicates, something is creating logs with new IDs instead of applying the same payload.
- **Missing session on phone**: The watch sends session first when you start a session; if a log arrives before the session, the phone creates a minimal session from the log. If the session never appears, check that **SyncApplyPhone.configure(modelContext:)** was called (e.g. from MainTabView `.onAppear`).

---

## 6. Manual Test Scenarios (Checklist)

Use this as a short checklist once the app runs.

| Area | What to do | What to check |
|------|------------|----------------|
| **Watch logging** | Start session, log Beer, Shot, Wine, Water | Session summary updates; haptics on log; pace badge (Good/Caution/Slow down). |
| **Watch pacing** | Log 2 shots within a few minutes | Warning (e.g. shot stacking) and haptic. |
| **Watch undo** | Log 2 drinks, tap Undo Last | Count drops by one; last drink removed. |
| **Watch end session** | End session | Summary clears; Start Session shown again. |
| **iPhone Tonight** | Start session, add drinks, End session | Same behavior as watch (counts, pace, undo, end). |
| **iPhone History** | After 1+ ended sessions | List shows sessions; tap one → detail with timeline and warnings. |
| **iPhone Insights** | After 1+ ended sessions | Charts and stats (drinks per session, avg length, warnings, most common drink). |
| **Sync W→P** | Log on watch only | Phone Tonight (or History) shows same session/logs after opening app. |
| **Sync P→W** | (When settings UI exists) Change settings on phone, open watch | Watch uses same sensitivity/cadence. |
| **Unit tests** | Cmd+U | All PacingEngine, SessionRepository, SyncPayloads tests pass. |

---

## 7. Summary

- **Unit tests**: Add **TakeCareAppTests** target, add the three test files, set host app, then **Cmd+U**.
- **iPhone**: Run the iOS scheme on simulator or device; use Tonight, History, Insights, Settings.
- **Watch**: Run the watch scheme on a watch simulator (ideally paired with an iPhone simulator) or a real watch.
- **Sync**: Use a **paired** simulator pair or real iPhone + Watch; trigger logs/session on watch and confirm they appear on phone; trigger settings push from phone and confirm watch reflects them.
- Use the **Manual test scenarios** table to regression-test after changes.
