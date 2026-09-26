## Why

Five apps (StreakFlame, Lineburst, Boltfall, Huefall, Wordfell) each carry their own copy of the same live-ops layer. The copies are a Firebase Remote Config transport, a pure resolver and an `@Observable` holder, about 1,700 lines in total, and their doc comments are word-for-word identical. The copies have started to drift: two window models, three meanings of "disabled", and two ways to report an out-of-range number. LiveOpsKit makes the CLAUDE.md live-ops rule one tested implementation instead of five.

## What Changes

- New Swift package **FallKit** with the LiveOpsKit products:
  - `LiveOpsCore`: pure keys, strict parsers, parameter readings, and resolution of switches, numbers and windows. Foundation only; builds for iOS, watchOS and macOS.
  - `LiveOpsStore`: the `@MainActor @Observable` holder and the fetch policy (no fetch in test hosts or synthetic runs).
  - `LiveOpsFirebase`: the single Remote Config transport. Only console-set, non-empty values count.
  - `LiveOpsTesting`: fake providers and golden fixtures that apps can load in their own tests.
  - `liveops`: a read-only CLI that prints resolved values and checks In-App Event dates from a manifest.
- Shared scripts: `check-boundary.sh`, `liveops.sh` and the local gate `ci-local.sh`.
- Docs: the canonical rule, a comparison of how the five apps behave, a migration map per app, and the manifest schema.
- **No app changes in this change.** Each app adopts the kit through its own plan in its own repo.

## Capabilities

### New Capabilities
- `live-ops-core`: parameter naming, strict parsing, readings, and the resolution of switches, numbers and windows.
- `live-ops-store`: the values holder, the activation and change rules, and the fetch gate.
- `live-ops-firebase`: the Remote Config transport contract.
- `live-ops-tooling`: the manifest, the `liveops` CLI, the fixtures, and the SDK boundary check.

### Modified Capabilities
- None. This is the first change in the repo.

## Impact

- **New public API** in FallKit `0.1.0`. Nothing consumes it yet.
- **Dependency:** `firebase-ios-sdk` in the range `12.17.0..<13.0.0`, linked on iOS only by `LiveOpsFirebase`.
- **Behaviour for the apps:** none until each one adopts the kit. The design lists where adoption will differ from an app's current code: the `.outOfRange` reading in S/L/B tooling, the strict day parser for Huefall, and not calling `onActivated` after a fetch error in S/L/H. Each difference is visible only in tooling, or is a rejection of values that were malformed anyway.
