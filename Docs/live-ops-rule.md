# The live-ops rule

This is the canonical text of the rule that all five apps' `CLAUDE.md` files carry, merged on 2026-09-26. The five copies list the same 12 points; only their examples differ. Each app's `CLAUDE.md` will link here once it adopts the kit.

## The rule (permanent)

**If a feature's timing or availability might need to change after release, it must ship with a Firebase Remote Config override.** A new build and an App Review must never be the only way to move a date or turn something off.

**In scope:**
- Seasons, limited-time events and collections, and any App Store In-App Event that goes with one.
- Limited cosmetics, offers, promos and sales.
- Rotating or featured content.
- Kill switches for new ad placements, ad-policy changes (placement on/off, frequency), and risky features, including anything that touches saved progress.

**Out of scope:** level and puzzle content, daily-challenge seeds, and balance-tested economy and scoring values. These stay bundled and change only with a build.

## Required behaviour, and where the kit enforces it

| # | Point | Enforced by |
|---|---|---|
| 1 | **Bundle first, then the last activation.** Bundled values apply until an override has ever been fetched. After that, the most recently activated override applies, including offline (the SDK's persistent cache). | `LiveOpsStore(values:)`, and `attach` reading `provider.current` |
| 2 | **Overrides never create anything.** An override may move, shorten, extend or disable a bundled item. Only bundled ids are read. Boolean flags only switch things *off*: `true` means "the bundle stands". | `LiveOpsResolve.isEnabled` · `windowOverrides(ids:)` · `LiveOpsWindowOverride.enabled` |
| 3 | **Naming.** `<kind>_<id>_<field>`, for example `event_harvest_moon_end`. Ids are sanitised to `[a-zA-Z0-9_]`, because the console rejects other keys as INVALID_KEY. | `LiveOpsKey.name` / `sanitise` / `isValid` |
| 4 | **Unset means no override.** Only console-set values count (`source == .remote`, non-empty). A malformed value is ignored for that key only. | `FirebaseLiveOpsProvider.current` · `LiveOpsParse` · per-field window parsing |
| 5 | **Fetch policy.** `fetchAndActivate` at launch and on foreground, with the SDK's default minimum interval. It never blocks the UI and never shows an error. | `FirebaseLiveOpsProvider.fetch` · `LiveOpsStore.fetch` (the app calls it on foreground) |
| 6 | **No fetch** in the unit-test host, in UI-test and screenshot runs, or under debug-override launch arguments whose state is synthetic. Plain Debug builds do fetch. | `LiveOpsGate.shouldFetch` with the app's `Policy` |
| 7 | **Pure resolution.** Every effective value is a pure, unit-tested function of the bundled value, the override and, where time matters, an injected date. | LiveOpsCore: no clock or environment (`PurityTests`) |
| 8 | **One transport.** Exactly one type imports `FirebaseRemoteConfig`. The rest of the app sees plain, SDK-free values. | `Sources/LiveOps/Firebase` · `Scripts/check-boundary.sh` |
| 9 | **Configuration, not measurement.** The fetch is not gated on analytics or ad consent, and it is disclosed in the privacy policy. Every change re-checks the App Privacy label. | App-side (privacy policy, label) · the transport has no consent input |
| 10 | **Nothing granted is taken back.** An override never revokes progress, rewards or purchases already granted. | App-side: resolution only decides what is *offered* |
| 11 | **In-App Events match.** If an In-App Event accompanies a window, its dates must match the *effective* window (bundle plus live Remote Config). | `liveops check-inapp-events` |
| 12 | **Bounded numbers.** Numeric overrides have bounds defined in code. An out-of-range value is treated as malformed: it is ignored and the bundle stands. It is **never clamped** to the nearest bound. | `LiveOpsParse.int(_:in:)` · `LiveOpsNumber` · `Reading.outOfRange` |

## Adding an override in an app

1. Add a case to the app's switch or number enum (conforming to `LiveOpsSwitch` / `LiveOpsNumber`), or a window to its catalogue.
2. Read it through the app's store at the moment the thing is *offered*, never where it was already granted.
3. Add resolver tests, and regenerate `liveops-manifest.json` (`Docs/manifest.md`).
4. Document the parameter (name, type, example value) in the app's parameter table.

## Leaving the console alone

An empty Firebase console must behave exactly like the bundle. Code changes never set, change or delete console parameters on their own; that happens only when the owner asks. The kit's tooling is read-only.
