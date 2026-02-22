# Take Care — Drink Pacing Coach: Architecture and How It All Works

This document explains the full setup: targets, data model, pacing logic, watch vs phone flows, and WatchConnectivity sync.

---

## 1. High-Level Architecture

The app has **two runnable targets** and one **shared codebase**:

| Target | Platform | Entry point | Role |
|--------|----------|-------------|------|
| **TakeCareApp** | iOS 18+ | `TakeCareApp.swift` (`@main`) | iPhone companion: tabs (Tonight, History, Insights, Settings), settings as source of truth, receives watch data |
| **TakeCareWatchApp** | watchOS 11+ | `TakeCareWatchApp.swift` (`@main`) | Watch: primary logging UI, session control, sends logs/sessions to phone, receives settings |

**Shared** code is compiled into **both** targets (same source, different binaries):

- **Shared/Constants** — Drink type IDs, sensitivity modes, event codes, cooldown constants.
- **Shared/Models** — SwiftData `@Model` types: `DrinkLog`, `Session`, `DrinkTypeConfig`, `PacingEvent`, `UserSettings`; plus `Schema` and container helpers.
- **Shared/PacingEngine** — Pure Swift (no SwiftData): rolling-window helpers, sensitivity presets, rule-based `PacingEngine.evaluate(...)`.
- **Shared/Repositories** — Protocol + implementation for each entity (Session, DrinkLog, PacingEvent, UserSettings, DrinkTypeConfig); all use a single `ModelContext`.
- **Shared/Sync** — `SyncPayloads` (encode/decode dictionaries), `WatchConnectivityManager` (WCSession), `SyncApplyPhone` / `SyncApplyWatch` (apply received data to SwiftData).

**Platform-specific** code:

- **WatchApp/** — `WatchSessionViewModel`, `WatchMainView`, `WatchHaptics` (watch-only).
- **iPhoneApp/** — `MainTabView`, tab ViewModels and Views (Tonight, History, Insights, Settings), iOS-only.
- **TakeCareApp/** — iOS app entry only.
- **TakeCareWatchApp/** — Watch app entry only.

So: one shared “engine” and data layer, two UIs (watch + phone) that both persist locally and sync over WatchConnectivity.

---

## 2. Data Model and Persistence (SwiftData)

Everything is stored **locally** with **SwiftData** (no cloud, no account).

### Schema (one container for all entities)

Defined in **Shared/Models/Schema.swift**:

- **Schema** = `DrinkLog`, `Session`, `DrinkTypeConfig`, `PacingEvent`, `UserSettings`.
- **ModelContainer** = persistent (disk) for both apps; **previewContainer** = in-memory for previews/tests.

Both the iPhone and the Watch have their **own** container (each device has its own SQLite store). Sync is what keeps them aligned.

### Entities (short)

| Model | Purpose |
|-------|--------|
| **DrinkLog** | One logged drink: `id`, `sessionId`, `timestamp`, `drinkTypeId`, `standardDrinkUnits`, `isAlcoholic`, `sourceDevice` ("watch" or "phone"). |
| **Session** | One “tonight” session: `id`, `startedAt`, `endedAt` (nil = active), `sensitivityMode`, `hydrationCadence`, `autoEndTimeoutMinutes`. |
| **DrinkTypeConfig** | Defaults per type (shot, beer, wine, cocktail, water): `id`, `displayName`, `defaultStandardUnits`, `isAlcoholic`, `isEnabled`, `sortOrder`. Seeded on first run. |
| **PacingEvent** | Warnings/reminders: `id`, `sessionId`, `timestamp`, `eventType`, `code`, `message`, `severity`. |
| **UserSettings** | Singleton-like: `displayName`, `weight`, `sensitivityMode`, `hydrationRemindersEnabled`, `hydrationCadence`, `notificationsEnabled`, `autoEndTimeoutMinutes`, `disclaimerAcceptedAt`. |

UUIDs are stored as strings (`idString`, `sessionIdString`) for SwiftData compatibility.

---

## 3. Repositories (Data Access)

Repositories wrap SwiftData and expose a small, testable API. Each has a **protocol** and a **concrete class** taking `ModelContext`.

| Repository | Main methods |
|------------|----------------|
| **SessionRepository** | `currentSession()`, `startSession(settings:)`, `endSession(_:)`, `session(by:)`, `sessions(from:to:)`, `endedSessions(limit:)`, `autoEndIfNeeded(timeoutMinutes:now:)` |
| **DrinkLogRepository** | `add(log:)`, `logs(for: sessionId)`, `lastLog(for:)`, `delete(log:)`, `undoLast(sessionId:)` |
| **PacingEventRepository** | `add(event:)`, `events(for: sessionId)`, `lastEvent(code:sessionId:withinMinutes:)` |
| **UserSettingsRepository** | `fetch()`, `save(_:)` |
| **DrinkTypeConfigRepository** | `all()`, `config(for: id)`, `update(_:)`, `seedDefaultsIfNeeded()` |

ViewModels get `ModelContext` from the environment and construct repositories with it. No SwiftData types cross the boundary into the PacingEngine—only snapshots (see below).

---

## 4. Pacing Engine (Rule-Based, No BAC)

The engine is **pure Swift**: no SwiftData, no UI. It’s the same on watch and phone.

### Inputs (snapshots, not SwiftData)

- **logs**: `[DrinkLogSnapshot]` — timestamp, drinkTypeId, standardDrinkUnits, isAlcoholic.
- **settings**: `UserSettingsSnapshot` — sensitivityMode, hydrationRemindersEnabled, hydrationCadence.
- **currentTime**: `Date`.
- **recentEvents**: `[PacingEventSnapshot]` — timestamp, code, severity (for dedupe).

### Output

- **PacingEngineResult**: `eventsToEmit: [PacingEventToEmit]`, `paceStatus: String` ("good" / "caution" / "slowDown"), `nextCheckIntervalSeconds`.

The **caller** (Watch or iPhone ViewModel) is responsible for:

- Turning snapshots from SwiftData into these input arrays.
- Persisting each `PacingEventToEmit` as a `PacingEvent` and triggering haptics/notifications.

### Rolling-window helpers (Shared/PacingEngine/RollingWindowHelpers)

Pure functions over `[DrinkLogSnapshot]` and a reference date:

- `alcoholicDrinkCount(in:minutes, from:date, logs:)`
- `standardDrinkUnits(in:minutes, from:date, logs:)`
- `timeSinceLastAlcoholicDrink(from:date, logs:)`
- `count(drinkTypeId:in:minutes, from:date, logs:)`
- `totalAlcoholicDrinkCount(from:date, logs:)`

All “from” is “as of this moment”; windows are “last N minutes” before that.

### Sensitivity presets (Shared/PacingEngine/SensitivityPresets)

One **SensitivityPreset** per mode (relaxed / balanced / strict): thresholds for “fast pace” (60 min), “escalation” (90 min), “rapid repeat” window, “shot stacking” window. The engine picks the preset from `settings.sensitivityMode`.

### Rules (order and dedupe)

1. **Rapid repeat** — 2+ alcoholic drinks in the preset window → caution + event `rapid_repeat` (unless that code fired in last 15 min).
2. **Fast pace** — Standard units in last 60 min > threshold → slowDown + event `fast_pace` (same 15 min cooldown).
3. **Escalation** — Standard units in last 90 min ≥ threshold → stronger warning + optional hydrate (15 min cooldown).
4. **Shot stacking** — 2+ shots in preset window → “Take a break” event (15 min cooldown).
5. **Hydration** — Every N alcoholic drinks (from settings), and not in last 20 min → “Water check” (20 min cooldown).
6. **Positive reinforcement** — A warning fired in the last hour and no alcoholic drink in 20 min → one “Nice reset” event (60 min cooldown).

Cooldowns use `recentEvents` so the same message doesn’t spam. Pace status is the “worst” among the rules that fired (e.g. escalation → slowDown).

---

## 5. Watch App: How It Works

### Entry and context

- **TakeCareWatchApp.swift**: `@main`, creates `TakeCareSchema.modelContainer`, injects it and shows `WatchMainView()`.
- **WatchMainView**: Gets `modelContext` from the environment, creates `WatchSessionViewModel(modelContext:)`, calls `SyncApplyWatch.configure(modelContext:)` once so the watch can apply incoming settings/drink types.

### WatchSessionViewModel

- Builds **SessionRepository**, **DrinkLogRepository**, **PacingEventRepository**, **UserSettingsRepository**, **DrinkTypeConfigRepository** from the same `modelContext`.
- **load()**: Ensures `UserSettings` exists (create default if none), seeds drink types if empty, loads `currentSession()` and refreshes logs + pace.
- **refreshLogsAndPace()**: Fetches logs for current session, builds `[DrinkLogSnapshot]` and `[PacingEventSnapshot]`, gets `UserSettingsSnapshot` from `UserSettings`, calls `PacingEngine.evaluate(...)`, updates `paceStatus` and `timeSinceLastDrink`.

### Logging flow (add drink)

1. Resolve **DrinkTypeConfig** for the tapped type (e.g. beer); if no session, **start one** from `UserSettings` and **send session** via `WatchConnectivityManager.sendSession(...)`.
2. Create **DrinkLog** (source = watch), save with **DrinkLogRepository**, then **send log** with `WatchConnectivityManager.sendLog(...)`.
3. Re-fetch logs, run **PacingEngine.evaluate(...)** with current snapshots and recent events.
4. For each **eventsToEmit**: create **PacingEvent**, save; play **WatchHaptics** (warning vs notification); set `lastWarningMessage`.
5. Update pace; if no events, play success haptic.

### Undo / Start / End

- **undoLast()**: Removes last log for current session via repository, refreshes, plays notification haptic.
- **startSession()**: Creates session from `UserSettings`, sends it with `sendSession(...)`, clears local session state.
- **endSession()**: Calls `sessionRepo.endSession(session)`, then `sendEndSession(sessionId:endedAt:)`, clears state.

So: every persistent change that the phone must know about (session start, each log, session end) is **written locally first**, then **sent** over WatchConnectivity.

### Receiving data on the watch

- **SyncApplyWatch** sets `onReceiveSettings` and `onReceiveDrinkTypes` on **WatchConnectivityManager**.
- When the phone pushes **application context** (settings dict), the delegate calls `onReceiveSettings?(dict)`; **applySettings** updates or creates **UserSettings** in the watch’s `modelContext`.
- When the phone sends **userInfo** (drink types), the delegate calls `onReceiveDrinkTypes?(items)`; **applyDrinkTypes** upserts **DrinkTypeConfig** in the watch’s store.

So the watch’s pacing and drink-type defaults stay in sync with the phone without the user opening the watch app’s “settings” screen.

---

## 6. iPhone App: How It Works

### Entry and tabs

- **TakeCareApp.swift**: `@main`, creates `TakeCareSchema.modelContainer`, shows `MainTabView().modelContainer(...)`.
- **MainTabView**: TabView with Tonight, History, Insights, Settings. On appear it calls **SyncApplyPhone.configure(modelContext)** (so received watch data is applied) and **SyncApplyPhone.pushSettingsToWatch(context)** (so the watch gets latest settings/drink types). On **willEnterForeground** it pushes settings again.

### Tonight tab

- **TonightViewModel**: Same pattern as the watch (repos, load, refreshLogsAndPace, addDrink, undo, start/end session). Logs are created with **source = phone**; no WatchConnectivity send from phone for logs (phone is the “receiver” for watch logs; phone-originated logs stay on phone only unless you later add phone→watch log sync).
- **TonightView**: Session summary card, pace card, “End session”, warning banner, recent logs list, “Log drink” buttons (flow layout), Undo. If no session, shows “Start session”.

### History tab

- **HistoryViewModel**: Loads **SessionRepository.endedSessions(limit: 200)**.
- **HistoryView**: List of ended sessions (date, time range, drink count, units). **NavigationLink** to **SessionDetailView(sessionId)**.
- **SessionDetailView**: Loads session, logs, and pacing events; shows summary (start/end, counts, units, water), drink-type breakdown, warnings list, and a **timeline** of drinks + events in order.

### Insights tab

- **InsightsViewModel**: Loads ended sessions, for each fetches logs and events; computes **SessionStats** (drink count, units, duration, warning count), aggregates (average duration, total warnings, drink-type counts, typical warning hour).
- **InsightsView**: Overview cards, **Swift Charts** (drinks per session, warnings per session), average session length, most common drink type, “typical fast-pace window” (hour when warnings often occur).

### Settings tab

- **SettingsView**: Placeholder list (sensitivity, hydration, auto-end, export, delete data, About with disclaimer). Real implementation would write to **UserSettings** and **DrinkTypeConfig**; after changes, calling **pushSettingsToWatch** again would sync to the watch.

### Receiving data on the phone

- **SyncApplyPhone** sets **onReceiveSession**, **onReceiveLog**, **onReceiveEndSession** on **WatchConnectivityManager**.
- **applySession**: If no session with that id exists, insert **Session** and save.
- **applyLog**: If no **DrinkLog** with that id, ensure **Session** exists (create with defaults if only the log arrived), insert **DrinkLog**, save. (Dedupe by log id.)
- **applyEndSession**: Find session by id, set **endedAt**, save.

So the phone’s SwiftData store is the **aggregate** of watch-originated sessions and logs; the phone never overwrites with stale data because of UUID dedupe and “session exists” checks.

---

## 7. WatchConnectivity Sync in Detail

### Single manager, two roles

- **WatchConnectivityManager.shared** is created at launch on both platforms; it sets **WCSession.default.delegate** and calls **activate()**.
- **Watch** uses: `sendSession`, `sendLog`, `sendEndSession` (outgoing); `onReceiveSettings`, `onReceiveDrinkTypes` (incoming, set by **SyncApplyWatch**).
- **Phone** uses: `pushSettings`, `pushSettingsAndDrinkTypes` (outgoing); `onReceiveSession`, `onReceiveLog`, `onReceiveEndSession` (incoming, set by **SyncApplyPhone**).

### Payload format (SyncPayloads)

All payloads are **dictionaries** (plist-safe: String, numbers, dates as `TimeIntervalSince1970`). A **type** key identifies the message:

- **session**: id, startedAt, sensitivityMode, hydrationCadence, autoEndTimeoutMinutes.
- **log**: id, sessionId, timestamp, drinkTypeId, standardDrinkUnits, isAlcoholic, sourceDevice.
- **endSession**: sessionId, endedAt.
- **settings**: sensitivityMode, hydrationRemindersEnabled, hydrationCadence, notificationsEnabled, autoEndTimeoutMinutes, optional displayName, weight, disclaimerAcceptedAt.
- **drinkTypes**: type + **items** array of { id, displayName, defaultStandardUnits, isAlcoholic, isEnabled, sortOrder }.

Parse helpers return typed tuples or optional dicts; apply code then updates SwiftData.

### Sending (watch → phone)

- If **session.isReachable** (other side is awake and reachable): **sendMessage** with the payload; on failure, fall back to **transferUserInfo**.
- Otherwise: **transferUserInfo** only. UserInfo is delivered in the background when the companion app runs later.

So logs and session lifecycles are never dropped: they’re either delivered immediately or queued.

### Sending (phone → watch)

- **updateApplicationContext** for settings (last-write-wins, always available when the watch next wakes).
- **transferUserInfo** for the drink-types payload (larger, one-off sync).

### Main queue

All delegate callbacks (didReceiveApplicationContext, didReceiveUserInfo, didReceiveMessage) dispatch to the main queue before calling the `onReceive*` closures, so UI and ModelContext updates stay on the main thread.

---

## 8. End-to-End Data Flow (Summary)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              WATCH (watchOS)                                  │
│  WatchMainView → WatchSessionViewModel (repos, PacingEngine, haptics)         │
│  • User taps Beer → DrinkLog saved → sendLog(...) → PacingEngine → events     │
│  • Start session → Session saved → sendSession(...)                           │
│  • End session → endedAt set → sendEndSession(...)                            │
│  • Receives: applicationContext (settings) → SyncApplyWatch → UserSettings   │
│  • Receives: userInfo (drinkTypes) → SyncApplyWatch → DrinkTypeConfig         │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ WCSession (sendMessage / transferUserInfo
                                    │ + updateApplicationContext / transferUserInfo)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHONE (iOS)                                      │
│  MainTabView → SyncApplyPhone.configure + pushSettingsToWatch on appear      │
│  • Receives: session → applySession (insert if new)                           │
│  • Receives: log → applyLog (insert if new, ensure session exists)             │
│  • Receives: endSession → applyEndSession (set endedAt)                       │
│  • Sends: settings + drink types → updateApplicationContext + transferUserInfo│
│  Tonight / History / Insights read from same SwiftData (sessions, logs, etc.) │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Watch**: Source of “live” logs and session lifecycle when the user is wearing the watch; settings and drink-type defaults come from the phone.
- **Phone**: Source of settings and drink-type config; recipient of watch sessions and logs; shows history and insights from the combined local store.

---

## 9. Tests (TakeCareAppTests)

- **PacingEngineTests**: Rolling-window helpers; 2 shots → warning; 4 units/90 min → escalation; hydration every 2 drinks; cooldown (same warning not repeated); sensitivity presets; good pace with no logs.
- **SessionRepositoryTests**: In-memory SwiftData; auto-end after timeout; no auto-end within timeout; endedSessions excludes active sessions.
- **SyncPayloadsTests**: Session, log, and endSession payload encode → parse round-trip.

Add the **TakeCareAppTests** target in Xcode, set the iOS app as the host, add the test files, and use **@testable import TakeCareApp** so the test target can see the app and Shared code.

---

## 10. Guardrails (Product)

- **No BAC** is computed or shown anywhere.
- **No “safe to drive”** messaging.
- **Disclaimer** in Settings/About: “If you’ve been drinking, do not drive” and that the app is not medical/legal advice.
- **Copy** for warnings is supportive and non-judgmental (e.g. “You’re pacing fast. Take a 20 min break.”).

This is the full setup and how it all works end to end.
