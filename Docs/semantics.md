# Live-ops semantics: the five apps compared

This file records how each app behaves today, read from its source on 2026-09-26, and what the kit does. Wherever the apps differ, the kit follows **Lineburst (L)** and exposes the difference as an explicit option. Nothing changes silently.

App letters: **S** StreakFlame · **L** Lineburst · **B** Boltfall · **H** Huefall · **W** Wordfell.

## Windows

| Case | S · L · B | H | W | Kit |
|---|---|---|---|---|
| Value type | ISO-8601 instant with offset | `LocalDate` (`YYYY-MM-DD`) | `LiveOpsDay` (`YYYY-MM-DD`) | `LiveOpsWindow<T>`: `Date` or `LiveOpsDay` |
| Start included? | yes (`start <= now`) | yes | yes | yes |
| End | **exclusive** (`now < end`) | **inclusive** day | **inclusive** day | `LiveOpsWindowEnd.exclusive` / `.inclusive` |
| Start-only override | start moves, bundled end stays | same | same | same |
| End-only override | end moves, bundled start stays | same | same | same |
| Malformed field | dropped; its siblings stand | same | same | same |
| `enabled=false` | window **removed** (`nil`) | window **closed**: upcoming before the (effective) start, past from it on | window **removed** | `LiveOpsDisabled.removed` / `.closed` |
| `enabled=true` | no effect (bundled windows are always on) | same | same | same |
| End before start | never live | upcoming before start, past from start (never open) | never live | never `.live` under either policy |
| End equal to start | never live (the end is excluded) | open that one day | live that one day | follows from the end policy |
| Override for an id not in the bundle | never read | never read | never read | only the given ids are read |
| Phase names | `isLive` bool only | upcoming / open / past | upcoming / live / over | `LiveOpsPhase` upcoming / live / over; H maps open→live and past→over |
| "Today" for day windows | — | `LocalDate(now, calendar: .current)` | Gregorian in the player's time zone | `LiveOpsDay(date:calendar:)`, always Gregorian, in the calendar's time zone |

## Values

| Case | All five | Kit |
|---|---|---|
| Bool spellings | `true/1/yes`, `false/0/no`, trimmed, any case; anything else `nil` | same |
| Int | trimmed; `Int(text)` (a leading `+` or `-` is accepted); out of range → `nil`, never clamped | same |
| Number out of range | falls back to the bundled value | same |
| Switch | `bundled && bool(value) != false`; bundled-off can't be switched on | same; `bundled` is passed at the call site |
| Empty or whitespace value | never reaches the resolver (the transport drops empties); parsers treat it as `nil` | same |
| `Reading` of whitespace-only | `.malformed` (`read` returns `.unset` only for `nil`) | same |

## Where the apps differ, and what adoption changes

| Case | Today | Kit | Who sees a difference |
|---|---|---|---|
| Reading of an out-of-range integer | S, L, B: `.malformed` · H, W: `.outOfRange(bounds)` | `.outOfRange(bounds)`; `isMalformed` covers both | S, L, B tooling and tests only. Resolution is the same |
| Instant parse | S, L, B: `ISO8601DateFormatter()` defaults | same | nobody |
| Day parse | H: loose (`2026-02-30`, `2026--10-1` and `+026-10-01` pass) · W: strict round-trip | strict (W) | H: values that were already wrong become malformed, so the bundle stands |
| `isValid` | `NSRegularExpression` `^[a-zA-Z][a-zA-Z0-9_]*$`, where `$` also matches before a final newline | scalar check, no trailing newline | nobody: keys come from code |
| Fetch reports `.error` with no error object | S, L, H: `onActivated()` runs · B, W: guarded | guarded (B, W) | nobody: the cached `current` is unchanged, so `onChange` never fires |
| Test-host detection | S, L, H: `XCTestCase` class · B: `XCTestConfigurationFilePath` · W: either | either | nobody in practice: both are set in a test host |
| Firebase "configured?" | S: its own analytics `configure()` · L, B, H, W: existing app, else plist → `configure()` | `configure` closure with a `.standard` default | nobody: S passes its own closure |
| `onChange` | a single closure in all five | a single closure | nobody |
| Logging | S, L, B: DEBUG `print` · H: os `Logger` (DEBUG) · W: os `Logger`, also in Release | an injected `log` closure | nobody: each app passes its own |

## Left in the apps

These stay in each app:
- Catalogues: features, placements, promos, offers, numbers with their bounds, and bundled calendars.
- Ad-policy structs: B `AdPolicyValues`, H and W `AdPolicy.Limits`.
- B's "placement is off when the whole ad stack is off" rule, built from two `isEnabled` calls.
- W's `FeatureFlags.masked(off:)`.
- The order of the key list.
- The launch arguments that block fetching.
- The foreground `fetch()` call.

## Test hosts

| Runner | `XCTestCase` class loaded | `XCTestConfigurationFilePath` | `LiveOpsGate.isTestHost` |
|---|---|---|---|
| An app's Xcode test host (XCTest or Swift Testing) | yes | yes | true |
| `swift test` in this package (swiftpm-testing-helper) | no | no | false |

The kit's own tests never build a transport, so the second row is harmless. App test hosts behave the same as today.
