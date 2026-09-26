# `liveops-manifest.json`, schema 1

The manifest lists everything one build reads from the Remote Config console. Each app **generates it from a unit test**, so it can never drift from the code. The `liveops` CLI and the golden fixtures resolve it with the same LiveOpsCore functions the app uses, so no tool has to compile app sources any more.

The model is `LiveOpsManifest` in LiveOpsCore. `Sources/LiveOps/Testing/Fixtures/catalog.manifest.json` is a complete example.

## Shape

```json
{
  "schemaVersion": 1,
  "app": "Lineburst",
  "parameters": [
    { "name": "event_harvest_moon_start",   "type": "instant", "bundled": "2026-10-01T00:00:00Z" },
    { "name": "event_harvest_moon_end",     "type": "instant", "bundled": "2026-10-16T00:00:00Z" },
    { "name": "event_harvest_moon_enabled", "type": "bool",    "bundled": "true" },
    { "name": "feature_adventure_enabled",  "type": "bool",    "bundled": "true" },
    { "name": "ad_undo_free_per_run",       "type": "int", "min": 1, "max": 5, "bundled": "3" }
  ],
  "windows": [
    { "kind": "event", "id": "harvest-moon", "type": "instant",
      "start": "2026-10-01T00:00:00Z", "end": "2026-10-16T00:00:00Z",
      "endPolicy": "exclusive", "whenDisabled": "removed", "inAppEvent": "Harvest Moon" }
  ]
}
```

## Fields

**Top level**

| Field | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | Must be `1`. Any other version is rejected. |
| `app` | string, optional | A display name only. **Never** put an identifier here: the repo and the CLI output may be public. |
| `parameters` | array | Every key the transport reads, in the order the app lists them. The transport's key list is `manifest.keys`. |
| `windows` | array, optional | Every bundled window: event, season or collection. |

**Parameter**

| Field | Type | Meaning |
|---|---|---|
| `name` | string | The console key. It must match `^[a-zA-Z][a-zA-Z0-9_]*$` and be at most 256 characters; decoding fails and names the key if not. |
| `type` | `instant` · `day` · `bool` · `int` | How the value is parsed (`LiveOpsParse`). |
| `min`, `max` | int | Inclusive bounds. Required for `int`, and `min <= max`. |
| `bundled` | string | The bundled value, spelled the way the console spells it. It must read as `applied`, so a bundled number sits inside its own bounds. |

**Window**

| Field | Type | Meaning |
|---|---|---|
| `kind`, `id` | string | Name the three parameters `<kind>_<sanitised id>_{start,end,enabled}`. Those three must be listed in `parameters`. |
| `type` | `instant` · `day` | The value type of `start` and `end`. |
| `start`, `end` | string | The bundled bounds. |
| `endPolicy` | `exclusive` · `inclusive` | Whether the end is still inside the window: instants are `exclusive`, days `inclusive` (`Docs/semantics.md`). |
| `whenDisabled` | `removed` · `closed` | What `enabled=false` does. `closed` is Huefall's model. |
| `inAppEvent` | string, optional | The App Store Connect reference name of the In-App Event that must match this window. Without it, an event matches when its reference name or deep link mentions the id (Lineburst's rule). |

`LiveOpsManifest.problems` (and `liveops validate`) report bad keys, duplicates, bundled values that don't read, missing window parameters, and window bounds that don't parse.

## Generating it in an app

Each app adds one unit test that builds the manifest from its own catalogue and writes it next to its docs. It runs on every test pass and fails when the file on disk differs:

```swift
@Test func liveOpsManifestIsCurrent() throws {
    let manifest = LiveOpsManifest(app: "Lineburst", parameters: LiveOps.parameters, windows: LiveOps.manifestWindows)
    #expect(manifest.problems.isEmpty)
    let url = repoRoot.appending(path: "Docs/liveops-manifest.json")
    let fresh = try manifest.encoded()
    if ProcessInfo.processInfo.environment["RECORD_LIVEOPS_MANIFEST"] == "1" { try fresh.write(to: url) }
    #expect(try Data(contentsOf: url) == fresh, "run with RECORD_LIVEOPS_MANIFEST=1 and commit the diff")
}
```

`encoded()` is stable (sorted keys, pretty-printed), so the file diffs cleanly.

## Running the tooling

```bash
Scripts/liveops.sh --manifest <app>/Docs/liveops-manifest.json --project <firebase-project> values
Scripts/liveops.sh --manifest <app>/Docs/liveops-manifest.json --project <firebase-project> --app-id <asc-app-id> check-inapp-events
Scripts/liveops.sh --manifest <app>/Docs/liveops-manifest.json validate
```

`LIVEOPS_TEMPLATE=<file>` and `LIVEOPS_APP_EVENTS=<file>` replace the fetches with saved JSON. Both fetches are read-only.

Limitation: In-App Events that accompany **day** windows are listed but not checked, because App Store Connect dates are instants and no app defines a time-zone rule for comparing them with days yet.
