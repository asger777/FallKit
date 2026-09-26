# Migration map: each app's live-ops code → LiveOpsKit

This map was read from each app's source on 2026-09-26. It is the input to every adoption plan, and each plan starts by re-running the golden fixtures against the app's **current** resolver.

**S** StreakFlame · **L** Lineburst · **B** Boltfall · **H** Huefall · **W** Wordfell.

## Shared by all five

| Today (each app) | Kit | Notes |
|---|---|---|
| `typealias LiveOpsValues` | `LiveOpsValues` | same type |
| `LiveOpsKey.name(_ kind: Kind, …)`, `Kind` enum | `LiveOpsKey.name(_ kind: LiveOpsKind, …)` | the app's `Kind` cases become `LiveOpsKind` constants or literals |
| `LiveOpsKey.sanitise` / `isValid` | same names | same behaviour (`Docs/semantics.md`) |
| `LiveOpsParse.bool` / `int(_:in:)` | same names | same behaviour |
| `LiveOpsParameter` + `Reading` | `LiveOpsParameter` + `Reading` | the kit adds `.outOfRange`; `isMalformed` covers it |
| `LiveOpsResolver.isEnabled(…)` | `LiveOpsResolve.isEnabled(_:bundled:values:)` or `(key:bundled:values:)` | the app's enums conform to `LiveOpsSwitch` |
| `LiveOpsResolver.value(_ number, …)` | `LiveOpsResolve.value(_:values:)` | the app's number enum conforms to `LiveOpsNumber` |
| `protocol LiveOpsProviding` | `LiveOpsProviding` | same two members |
| `final class LiveOps` (values, attach, fetch, apply, onChange, hasProvider) | `LiveOpsStore` | the app keeps a thin `LiveOps` facade holding a `LiveOpsStore`, plus its resolved accessors |
| `startIfAllowed()` | `store.start(allowed: LiveOpsGate.shouldFetch(.current(...), policy:), make: { FirebaseLiveOpsProvider.make(keys:log:) })` | |
| `static func shouldFetch(...)` | `LiveOpsGate.shouldFetch(_:policy:)` | the app supplies its `Policy` and screenshot flag |
| `Analytics/LiveOpsRemote.swift` | `FirebaseLiveOpsProvider` | **delete the app file**; the boundary check expects zero app importers |
| stub providers in tests | `MemoryLiveOpsProvider` (`.immediate` / `.deferred`) | from `LiveOpsTesting` |
| `Scripts/liveops/run.sh` + `main.swift` | `FallKit/Scripts/liveops.sh` + `liveops-manifest.json` | the app emits its manifest from a unit test |
| `check-*-boundary.sh` / single-importer tests | `FallKit/Scripts/check-boundary.sh <app sources>` | expected count **0** |

## Per app

### S · StreakFlame (instant windows, end exclusive, disabled → removed)

| Today | Kit |
|---|---|
| `LiveOpsParse.date` / `string` | `LiveOpsParse.instant` / `string(instant:)` |
| `LiveOpsEvent` | `LiveOpsWindow<Date>` plus the app's id |
| `LiveOpsWindowOverride`, `LiveOpsEventOverride` | `LiveOpsWindowOverride<Date>`, `[String: LiveOpsWindowOverride<Date>]` |
| `eventOverride(_:eventIDs:)` | `windowOverrides(kind: .event, ids:values:parse: LiveOpsParse.instant)` |
| `effectiveWindow` / `isLive` / `live` | `effective(bundled:override:)` / `isLive(_:at:end: .exclusive)` |
| `LiveOpsFeature`, `LiveOpsPromo` | conform to `LiveOpsSwitch` |

- **Stays in the app:** `ShieldRules`-derived bounds, the promo catalogue, key ordering, `--uitest` / `-demoData` / `-StreakflameForce*` in its `Policy`.
- **Transport:** `configure: { AnalyticsService.configure(); return FirebaseApp.app() != nil }`.
- **Widgets and Watch** link `LiveOpsCore` only.
- **Before adopting:** Firebase 11.15 → 12.x.

### L · Lineburst (the reference; instant windows, end exclusive, disabled → removed)

| Today | Kit |
|---|---|
| `Event.contains`, `EventCalendar.*`, `WindowOverride`, `EventScheduleOverride` | `LiveOpsWindow<Date>` / `LiveOpsWindowOverride<Date>` / `effective` / `isLive(end: .exclusive)` |
| `EventCalendar.ends` | `effective(...)?.end`, which is `nil` when disabled. Note that an inverted override still has an end; today's countdown code has the same behaviour. |
| `LiveOpsFeature.bundled(in: TuningConfig)` | `LiveOpsSwitch`, with `bundled:` passed at the call site from the run's `TuningConfig` |
| `AdPlacement.liveOpsParameterName` | `LiveOpsKey.name(.ad, id:, field: "enabled")` |

- **Stays in the app:** `EventSchedule`, `TuningConfig`, the juice switches, `AdGateDriver` and `EventSchedule` launch arguments, and `BLOCKRISE_DISABLE_ANALYTICS` (as a `blockedFlags` entry).
- **Screenshot flag:** `ScreenshotState.isActive`.

### B · Boltfall (instant windows, end exclusive, disabled → removed)

| Today | Kit |
|---|---|
| `LiveOpsWindow` (a concrete struct) | `LiveOpsWindow<Date>` |
| `effectiveWindow(for:values:)` | `windowOverride` + `effective` |
| `isLive` / `liveEvents` | `isLive(_:at:end: .exclusive)` over the app's list |
| `LiveOpsKey.snakeCase` | `LiveOpsKey.snakeCase` |

- **Stays in the app:** `AdPolicyValues` / `adPolicy()` (built from `LiveOpsNumber`s); the rule that a placement is off when the whole ad stack is off (`isEnabled(.ads) && isEnabled(placement)`); the `-debug.` prefix (`blockedArgumentPrefixes`).
- **Test host:** the kit checks the class **or** the variable, a superset of Boltfall's variable-only check.

### H · Huefall (day windows, end inclusive, disabled → **closed**)

| Today | Kit |
|---|---|
| `LiveOpsParse.localDate` / `LocalDate` | `LiveOpsParse.day` / `LiveOpsDay`. **Stricter:** `2026-02-30`, `2026--10-1` and `+026-10-01` become malformed. |
| `SeasonWindowOverride`, `seasonOverrides` | `LiveOpsWindowOverride<LiveOpsDay>`, `windowOverrides(kind: .season, …, parse: LiveOpsParse.day)` |
| `SeasonWindowResolution.effective` | `effective(bundled:override:)` |
| `SeasonWindowResolution.state` (`upcoming/open/past`) | `phase(bundled:override:at:end: .inclusive, whenDisabled: .closed)`; map `.live`→open and `.over`→past |
| `BundledSeasonWindow` | `LiveOpsWindow<LiveOpsDay>` plus the app's id |
| `LiveOpsSwitch` (the app's enum) | **rename** it (for example `HuefallSwitch`) and conform it to the kit's `LiveOpsSwitch` protocol, to avoid the name clash |

- **Stays in the app:** `AdPolicy.Limits` / `adLimits` (from `LiveOpsNumber`s), `SeasonStore`, the kind `.ads` (plural), the `-debug.` prefix.
- **Bridge:** `LocalDate` ↔ `LiveOpsDay`. "Today" becomes `LiveOpsDay(date: now, calendar: .current)`, always counted on the Gregorian calendar.
- **Test framework:** XCTest can call the kit unchanged.

### W · Wordfell (day windows, end inclusive, disabled → removed)

| Today | Kit |
|---|---|
| `LiveOpsDay` | `LiveOpsDay` (Wordfell's is the reference; the same strict parser) |
| `LiveOpsWindow.Phase` (`upcoming/live/over`) | `LiveOpsPhase`, identical names |
| `LiveOpsResolver.window(for:values:)` | `windowOverride` + `effective` |
| `LiveOpsCatalog.Switch` string ids | `isEnabled(key:bundled:values:)` |
| `ThemedCollection.phase(on:calendar:)` | `phase(of:at: LiveOpsDay(date:calendar:), end: .inclusive)` |

- **Stays in the app:** `FeatureFlags.masked(off:)`, `disabledFeatures`, `switchedOffPlacements`, `effectiveCollections`, `AdPolicy.Limits`, and `-screenshotScene` / `-tokenGallery` in its `Policy`.
- **Screenshot flag:** `ScreenshotMode.isActive`.
- **Logging:** its Release-level `Logger` goes into the transport's `log` closure.

## Tests: what moves and what stays

| Moves to the kit (already ported) | Stays in each app |
|---|---|
| key naming, sanitising, `isValid`, `snakeCase` | its catalogue: every id, every key count |
| bool, int, instant and day parsing | bundled values and bounds (`TuningConfig`, `ShieldRules`, `AdPolicy`) |
| parameter readings | wiring: consumers re-render or re-cache on `onChange` |
| the switch off-only rule; number bounds fallback | `EventSchedule` / `SeasonStore` / `effectiveCollections` behaviour |
| window override, effective window, phase, disabled policies | the gate's app-specific launch arguments (counts, names) |
| holder: attach, activation, apply, start | the manifest-is-current test (new) |
| gate mechanics | the golden fixtures run against the old resolver, then the kit (new) |
