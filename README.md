# FallKit

Swift packages shared by five iOS apps: StreakFlame, Lineburst, Boltfall, Huefall and Wordfell.

The first kit is **LiveOpsKit**: Firebase Remote Config overrides that can move, shorten, extend or switch off what an app ships with, and never create anything new. The rule it implements is [`Docs/live-ops-rule.md`](Docs/live-ops-rule.md).

## Products

| Product | What it is | Imports | Platforms |
|---|---|---|---|
| `LiveOpsCore` | Keys, strict parsers, readings, resolution of switches, numbers and windows, the manifest and report. Pure. | Foundation | iOS 17 · watchOS 10 · macOS 14 |
| `LiveOpsStore` | `@Observable` holder (`LiveOpsStore`) and fetch policy (`LiveOpsGate`) | LiveOpsCore, Observation | iOS 17 · watchOS 10 · macOS 14 |
| `LiveOpsFirebase` | `FirebaseLiveOpsProvider`, the one Remote Config transport | LiveOpsStore, FirebaseRemoteConfig | iOS 17 (empty module elsewhere) |
| `LiveOpsTesting` | `MemoryLiveOpsProvider` and the golden fixtures. **Link it from test targets only.** | LiveOpsStore | iOS 17 · watchOS 10 · macOS 14 |
| `liveops` | CLI: `values`, `check-inapp-events`, `validate` | LiveOpsCore | macOS 14 |

Firebase is declared as `12.17.0..<13.0.0` and is linked only when `LiveOpsFirebase` is built for iOS. Each app keeps its own exact Firebase pin.

## Install (XcodeGen)

```yaml
packages:
  FallKit:
    url: https://github.com/asger777/FallKit
    exactVersion: 0.1.0
    # while developing locally instead:  path: ../FallKit

targets:
  App:
    dependencies:
      - package: FallKit
        product: LiveOpsStore
      - package: FallKit
        product: LiveOpsFirebase
  AppTests:
    dependencies:
      - package: FallKit
        product: LiveOpsTesting
  Widgets:                     # or a watchOS target: Core only, no Firebase
    dependencies:
      - package: FallKit
        product: LiveOpsCore
```

## Quick start

```swift
import LiveOpsCore
import LiveOpsFirebase
import LiveOpsStore

enum Feature: String, LiveOpsSwitch, CaseIterable {
    case adventure
    var parameterName: String { LiveOpsKey.name(.feature, id: rawValue, field: "enabled") }
}

struct FreeUndos: LiveOpsNumber {
    let parameterName = "ad_undo_free_per_run"
    let bundled = 3
    let bounds = 1...5
}

@MainActor
final class LiveOps {
    static let shared = LiveOps()
    let store = LiveOpsStore()

    static var parameters: [LiveOpsParameter] {
        Feature.allCases.map { $0.parameter() } + [FreeUndos().parameter]
    }

    /// Launch: attach the transport unless this is a test host or a synthetic run.
    func start() {
        let allowed = LiveOpsGate.shouldFetch(.current(), policy: .init(blockedArgumentPrefixes: ["-debug."]))
        store.start(allowed: allowed) { FirebaseLiveOpsProvider.make(keys: Self.parameters.keys) }
    }

    func isEnabled(_ feature: Feature) -> Bool { LiveOpsResolve.isEnabled(feature, values: store.values) }
    var freeUndos: Int { LiveOpsResolve.value(FreeUndos(), values: store.values) }
}
// On foreground: LiveOps.shared.store.fetch()
```

Windows (events, seasons, collections):

```swift
let bundled = LiveOpsWindow(start: eventStart, end: eventEnd)            // Date, or LiveOpsDay for day windows
let override = LiveOpsResolve.windowOverride(kind: .event, id: "harvest-moon",
                                             values: store.values, parse: LiveOpsParse.instant)
let phase = LiveOpsResolve.phase(bundled: bundled, override: override, at: now,
                                 end: .exclusive, whenDisabled: .removed)  // .upcoming / .live / .over / nil
```

## Tooling

```bash
Scripts/liveops.sh --manifest <app>/Docs/liveops-manifest.json --project <firebase-project> values
Scripts/liveops.sh --manifest <app>/Docs/liveops-manifest.json --project <firebase-project> --app-id <asc-app-id> check-inapp-events
Scripts/check-boundary.sh <app>/Sources      # no app file may import FirebaseRemoteConfig
```

Both are read-only. The manifest format is in [`Docs/manifest.md`](Docs/manifest.md).

## Docs

- [`Docs/live-ops-rule.md`](Docs/live-ops-rule.md): the rule, and where the kit enforces each point
- [`Docs/semantics.md`](Docs/semantics.md): how the five apps behave, and what the kit does where they differ
- [`Docs/migration.md`](Docs/migration.md): each app's types mapped to kit types
- [`Docs/manifest.md`](Docs/manifest.md): `liveops-manifest.json`
- [`CHANGELOG.md`](CHANGELOG.md)

## Development

```bash
Scripts/ci-local.sh     # the gate before every push: lint, tests, simulator builds, boundary self-test, OpenSpec
```

There is no GitHub workflow; the local gate is the gate. Specs live in `openspec/`.

## License

MIT, see [LICENSE](LICENSE).
