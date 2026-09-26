# Changelog

FallKit follows [semantic versioning](https://semver.org). Until `1.0.0`, a minor version may change the API.

## [Unreleased]

## [0.1.0] — 2026-09-27

First release: LiveOpsKit. Nothing consumes it yet; each app adopts it through its own plan.

### Added — LiveOpsKit
- `LiveOpsCore`:
  - `LiveOpsKind` and `LiveOpsKey` (`name`, `sanitise`, `snakeCase`, `isValid`).
  - Strict parsers in `LiveOpsParse` (`bool`, `int(_:in:)`, `instant`, `day`), and `LiveOpsDay`.
  - `LiveOpsParameter` with `Reading` (`unset`, `applied`, `malformed`, `outOfRange`).
  - The `LiveOpsSwitch` and `LiveOpsNumber` protocols.
  - Generic windows (`LiveOpsWindow<T>`, `LiveOpsWindowOverride<T>`), with end policies (`exclusive`, `inclusive`) and disabled policies (`removed`, `closed`), resolved by `LiveOpsResolve`.
  - `LiveOpsTemplate`, `LiveOpsManifest` and `LiveOpsReport`.
- `LiveOpsStore`: `LiveOpsProviding`, `LiveOpsStore` and `LiveOpsGate`.
- `LiveOpsFirebase`: `FirebaseLiveOpsProvider`, linked on iOS only.
- `LiveOpsTesting`: `MemoryLiveOpsProvider`, `LiveOpsFixtures`, and 14 golden fixtures against `catalog.manifest.json`.
- The `liveops` CLI (`values`, `check-inapp-events`, `validate`).
- Scripts: `liveops.sh`, `check-boundary.sh` with a self-test, and `ci-local.sh`.
- Docs: the rule, the comparison of the five apps, the migration map, and the manifest schema.
- `Examples/ConsumerCheck`: an XcodeGen app that uses the kit by URL + tag, checked with Firebase pinned to exactly 12.18.0 and 12.17.0, plus a Core-only watchOS target.
- OpenSpec capabilities `live-ops-core`, `live-ops-store`, `live-ops-firebase` and `live-ops-tooling` (34 requirements).

### Behaviour notes for adopting apps
- S, L and B tooling and tests see `.outOfRange` where they saw `.malformed`. Resolution is unchanged.
- Huefall's day parser becomes strict, so values that were already invalid (such as `2026-02-30`) become malformed.
- After a fetch reports `.error` with no error object, `onActivated` no longer runs (S, L and H). This isn't observable: the values are unchanged.
