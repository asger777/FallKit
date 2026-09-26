## Context

The five live-ops layers share one template, but they have drifted apart. Findings from a read of all 18 source files and 217 tests (2026-09-26):

| Topic | S · L · B | H | W |
|---|---|---|---|
| Window values | `Date` instants (ISO-8601 with an offset) | `LocalDate` (loose `YYYY-MM-DD`) | `LiveOpsDay` (strict `YYYY-MM-DD`) |
| End of window | exclusive: `start <= now < end` | inclusive day | inclusive day |
| `enabled=false` | window removed (`nil`) | window **closed**: upcoming before start, past from start | window removed |
| Phase names | none (a bool `isLive`) | upcoming / open / past | upcoming / live / over |
| Out-of-range number reading | `.malformed` | `.outOfRange(bounds)` | `.outOfRange(bounds)` |
| Fetch with `status == .error` and no error object | S, L: `onActivated()` runs · B: guarded | `onActivated()` runs | guarded |
| Test-host detection | `XCTestCase` class (S, L) · env var (B) | class | class **or** env var |

The following are identical in all five apps: `sanitise` and `isValid`, the bool and int parsers, the rule that a switch can only turn something off, falling back to the bundled value when a number is out of range, `source == .remote` with a non-empty value, attach applying the cache without notifying, and `onChange` firing only when the values actually change.

## Goals / Non-Goals

**Goals:**
- One implementation that reproduces each app's current behaviour. Every difference is an explicit option; none is a silent change.
- A pure, heavily tested core with no clock, no environment and no SDK.
- Tooling that no longer compiles app source files.

**Non-Goals:**
- Changing any app. Adoption plans are written per app later.
- Writing to a Firebase console or to App Store Connect.
- Catalogues: feature lists, calendars, ad-policy structs and key ordering stay in the apps.
- Supporting Firebase 11.

## Decisions

1. **Kinds are an open string type** (`LiveOpsKind`, `ExpressibleByStringLiteral`, with constants such as `.event` and `.season`). The five apps use seven kinds between them, so a closed enum would not fit.
2. **One generic window, `LiveOpsWindow<T: Comparable>`, plus an end policy.** `LiveOpsWindowEnd.exclusive` covers the instant apps (S, L, B) and `.inclusive` covers the day apps (H, W).
   - The phase rule is: `at < start` → `.upcoming`; `at` past the end (by `>=` or `>` depending on the policy) → `.over`; otherwise `.live`.
   - An inverted window therefore never reads `.live` under either policy, which matches all five apps.
   - *Alternative:* two separate window types. Rejected because the override and parsing logic is identical for both.
3. **What "disabled" means is set by the caller:** `LiveOpsDisabled.removed` (S, L, B, W) or `.closed` (H).
   - `effective(bundled:override:)` returns `nil` when disabled; this is the removed model.
   - `phase(bundled:override:at:end:whenDisabled:)` returns `nil` for `.removed`. For `.closed` it returns `.upcoming` before the effective start and `.over` from the start on.
   - H maps `open` → `.live` and `past` → `.over` in its own code.
4. **Switches take `bundled` at the call site** (`isEnabled(key:bundled:values:)`, default `true`). Lineburst's bundled flags depend on the saved `TuningConfig`, and Wordfell identifies features by string ID, so a stored `bundled` property can't cover every app. The `LiveOpsSwitch` protocol carries only `parameterName`.
5. **`Reading` gains `.outOfRange(bounds)`**, from H and W, along with `isMalformed`, which is true for both `.malformed` and `.outOfRange`. Resolution is unchanged: out of range always falls back to the bundled value. The difference shows only in S/L/B tooling output and tests.
6. **Strict day parser** (W's `LiveOpsDay`): exactly 4-2-2 digits, checked by a round trip through a UTC Gregorian calendar. Huefall's looser parser used to accept values like `2026-02-30`; under the kit they become malformed, which is safer. `LiveOpsDay(date:calendar:)` gives the day apps a pure "today".
7. **Instant parser:** `ISO8601DateFormatter` with its default `.withInternetDateTime`. That means an offset is required, fractional seconds and date-only strings are rejected, and values are normalised to UTC `Z` for readings. A new formatter is created per call, because the type is not `Sendable`. This is the same as S, L and B.
8. **Holder:** `LiveOpsStore(values:)` has a single `onChange` closure, the same as all five apps (the plan's "several observers" idea was dropped to avoid new behaviour). Attach applies the cache without notifying and starts one fetch. Activation notifies only when the values actually change. It is **not** a singleton; each app keeps its own `shared`.
9. **Gate:** a pure `LiveOpsGate.shouldFetch(_ launch: LaunchContext, policy: Policy)`.
   - `Policy` holds the blocked arguments, blocked argument prefixes and blocked environment flags (`key == "1"`).
   - `isTestHost` is the union of the apps' checks: the `XCTestCase` class **or** `XCTestConfigurationFilePath`.
   - `isScreenshotRun` is supplied by the app.
10. **Transport:** `FirebaseLiveOpsProvider.make(keys:configure:log:)`.
    - `configure` is a closure that returns whether Firebase is ready. The default is `.standard`: an existing `FirebaseApp` → true; a plist present → `FirebaseApp.configure()` then true; otherwise false. S passes its own closure.
    - On `status == .error` it does **not** call `onActivated` (the B and W behaviour). This is not observable for S, L and H, because an unchanged `current` never fires `onChange`.
    - Logging goes through the injected closure, so each app decides whether it logs in Release.
11. **Firebase is linked on iOS only** (`condition: .when(platforms: [.iOS])`), and the file is guarded with `#if canImport`. A compile-time `#error` catches a broken condition on iOS.
12. **The manifest replaces compiled-in app sources for the tooling.** Each app will emit `liveops-manifest.json` from a unit test. The CLI resolves windows and parameters with the same Core functions the app uses.

## Risks / Trade-offs

- [A generic API is harder to read than five concrete ones] → `Docs/migration.md` maps every current call site to its kit equivalent.
- [Adoption could still shift behaviour] → Golden fixtures in `LiveOpsTesting` are run against each app's *current* resolver before it migrates, and again after.
- [Firebase resolution is heavy for Core-only consumers] → SwiftPM resolves the whole graph, but Firebase is only compiled when `LiveOpsFirebase` is linked on iOS (verified in Section 1).
- [Public repo] → The tooling takes every project and app ID as an argument, and the ASC token stays in `~/.appstoreconnect`.

## Migration Plan

This change ships FallKit `0.1.0` with no consumers. Rollback means not adopting it. Adoption order and steps are in each app's own plan (Lineburst first).

## Open Questions

- None blocking. The instant/day and removed/closed differences are handled by options (decisions 2 and 3).
