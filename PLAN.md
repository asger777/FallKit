# FallKit — LiveOpsKit Build Plan

**One line.** FallKit is the Swift package repo shared by Asgar's five iOS apps. **LiveOpsKit** is its first family of products: the Firebase Remote Config live-ops layer that each app currently has its own copy of.

**Repo.** https://github.com/asger777/FallKit (public) · local `~/Documents/GitHub/OWN/FallKit`
**Stack.** Swift Package Manager · swift-tools 6.0 · Swift 6 language mode · iOS 17, watchOS 10, macOS 14 (macOS is only for tests and the CLI)
**Consumers (later, separate plans).** Lineburst (pilot) → Boltfall → Huefall → Wordfell → StreakFlame

---

## Scope

**In scope:** everything inside this repo: the package, its tests, the CLI, scripts, docs, the local gate and the first tag.

**Out of scope for this plan:**
- Any change in the five app repos. Lineburst's adoption gets its own plan, written after Section 13.
- Any change to a Firebase console. The kit never writes to a console.
- StreakFlame's Firebase 11 → 12 upgrade.

**The kit must serve all five apps, not only Lineburst.** Lineburst is the reference implementation because the CLAUDE.md live-ops rule was written against it. Where the five apps differ, the kit supports each difference or documents it (see Section 4.1).

## How this plan works

- **14 sections, 0 through 13**, done in order. `## [ ]` means not done, `## [x]` means done. Tasks and **Done when** boxes are ticked one by one.
- A section is done only when every **Done when** box is ticked.
- **Tests are written with the code**, not afterwards. A section is never committed with failing or missing tests.
- **The local gate before every push:** `swift test` + `Scripts/ci-local.sh` (lint + iOS and watchOS simulator builds). A red gate blocks the push.

## Git flow — confirmed 2026-09-26

Proposed: the same speed-first flow as the casual repos, **with one difference: version tags are required from day one.** SPM resolves packages by tag, so an untagged kit can't be used by URL.

1. Work goes directly to `main` with conventional commits, e.g. `feat(core): generic window override`.
2. Tags use semantic versioning:
   - `0.x.y` until the pilot app ships a release built with the kit. In `0.x`, a minor bump may break the API.
   - `1.0.0` once two apps are on it. From then on, breaking changes need a major bump.
3. Every tag has a `CHANGELOG.md` entry and a GitHub release.
4. **Public repo hygiene:** no secrets, keys, team IDs, Firebase project IDs, app IDs or account emails anywhere in the repo. Anything app-specific is passed in as an argument.

---

## Asgar's queue

| # | Item | From | Tick |
|---|---|---|---|
| 1 | Approve this plan | — | ☑ 2026-09-26 |
| 2 | Confirm the git flow above (main + tags), commit and push section by section | — | ☑ 2026-09-26 |
| 3 | Pick a license for the public repo. **Defaulted to MIT** (the recommendation) so work could start; change it if you want another | S0 | ☐ confirm |
| 4 | CI on GitHub Actions | S12 | ☑ 2026-09-26 — **no CI**; the local gate is the only gate |
| 5 | Approve tagging `0.1.0` | S13 | ☑ 2026-09-26 — "don't stop until the plan finishes" |

---

## Section index

| # | Section | Product |
|---|---|---|
| 0 | Repo bootstrap | — |
| 1 | Package manifest | all |
| 2 | Keys and strict parsing | LiveOpsCore |
| 3 | Parameters and readings | LiveOpsCore |
| 4 | Resolution: switches, numbers, windows | LiveOpsCore |
| 5 | Holder and fetch policy | LiveOpsStore |
| 6 | Firebase transport | LiveOpsFirebase |
| 7 | Test helpers | LiveOpsTesting |
| 8 | Conformance suite and golden fixtures | tests |
| 9 | `liveops` CLI | executable |
| 10 | SDK boundary check | script |
| 11 | Documentation and OpenSpec | docs |
| 12 | The local gate | infra |
| 13 | Consumption check and tag 0.1.0 | release |

---

## Target layout

One folder per kit under `Sources/` and `Tests/`; future kits (Seeded, Save, …) sit next to `LiveOps/`.

```
FallKit/
├── Package.swift
├── Sources/
│   └── LiveOps/
│       ├── Core/        → LiveOpsCore       Foundation only · iOS, watchOS, macOS
│       │   ├── LiveOpsValues.swift       typealias LiveOpsValues = [String: String]
│       │   ├── LiveOpsKind.swift         app-defined kinds (event, feature, ad, season, …)
│       │   ├── LiveOpsKey.swift          name / sanitise / isValid / snakeCase
│       │   ├── LiveOpsParse.swift        bool / int(in:) / instant / day, all strict
│       │   ├── LiveOpsDay.swift          YYYY-MM-DD calendar day, round-trip validated
│       │   ├── LiveOpsParameter.swift    ValueType + Reading (unset/applied/malformed/outOfRange)
│       │   ├── LiveOpsSwitch.swift       protocol: switches only turn things off
│       │   ├── LiveOpsNumber.swift       protocol: bundled + bounds
│       │   ├── LiveOpsWindow.swift       Window<T>, WindowOverride<T>, Phase
│       │   ├── LiveOpsResolve.swift      pure resolution functions
│       │   └── LiveOpsManifest.swift     liveops-manifest.json model (shared with the CLI)
│       ├── Store/       → LiveOpsStore      Observation · @MainActor
│       │   ├── LiveOpsProviding.swift
│       │   ├── LiveOpsStore.swift        @Observable holder
│       │   └── LiveOpsGate.swift         shouldFetch + isTestHost
│       ├── Firebase/    → LiveOpsFirebase   the only FirebaseRemoteConfig import (iOS)
│       │   └── FirebaseLiveOpsProvider.swift
│       ├── Testing/     → LiveOpsTesting    fakes + golden fixtures (bundled resources)
│       │   ├── MemoryLiveOpsProvider.swift
│       │   ├── LiveOpsFixtures.swift
│       │   └── Fixtures/                 Remote Config templates + expected readings
│       └── CLI/         → liveops           executable: values, check-inapp-events
├── Tests/
│   └── LiveOps/
│       ├── CoreTests/
│       ├── StoreTests/
│       └── CLITests/
├── Scripts/
│   ├── liveops.sh              fetches template + app events, runs the CLI
│   ├── check-boundary.sh       "no app file imports an SDK the kit owns"
│   └── ci-local.sh             the local gate
├── Docs/
│   ├── live-ops-rule.md        the canonical 12-point rule
│   ├── semantics.md            edge-case behaviour, five apps compared
│   ├── migration.md            each app's types → kit types
│   └── manifest.md             liveops-manifest.json schema
├── Examples/ConsumerCheck/     XcodeGen app using the kit by URL + tag
├── openspec/                   specs/live-ops/spec.md
├── .swiftlint.yml
├── README.md · CHANGELOG.md · CLAUDE.md · LICENSE · PLAN.md
```

Package rules for future kits:
1. Each kit has up to four kinds of product: `<Kit>Core` (pure), `<Kit>Store` (holds state), `<Kit><SDK>` (the adapter) and `<Kit>Testing`.
2. Dependencies only point downward. Only the adapter imports its SDK, and kits never depend on each other's adapters.
3. There is no common "utilities" module until two kits need the same thing.
4. The whole repo has one version tag.

---

## [x] Section 0 — Repo bootstrap

**Goal.** An empty but well-formed repo.

- [x] `.gitignore`: `.build/`, `.swiftpm/`, `DerivedData/`, `*.xcodeproj` (the package doesn't commit one), `.DS_Store`
- [x] `README.md` stub: what FallKit is, the product list, status "pre-0.1"
- [x] `LICENSE` per Asgar's queue #3
- [x] `CLAUDE.md`, with these rules:
  - public repo, no identifiers;
  - pure code in LiveOpsCore;
  - exactly one file imports FirebaseRemoteConfig;
  - the kit never writes to a console;
  - behaviour changes need a CHANGELOG entry.
- [x] `openspec init` (schema `spec-driven`), with the live-ops rule in `config.yaml` context
- [x] `.swiftlint.yml`, based on Huefall's and Wordfell's config: line length 140/200, type body 350, file 600

**Done when**
- [x] First commit pushed to `main`
- [x] `openspec validate --all` passes on the empty spec set

## [x] Section 1 — Package manifest

**Goal.** `Package.swift` declares all five products; only one of them depends on Firebase.

- [x] Set `// swift-tools-version: 6.0` and `swiftLanguageModes: [.v6]`, with complete strict concurrency on every target
- [x] Platforms: `.iOS(.v17), .watchOS(.v10), .macOS(.v14)`
- [x] Declare these products:

  | Product | Type | Depends on |
  |---|---|---|
  | `LiveOpsCore` | library | nothing |
  | `LiveOpsStore` | library | Core |
  | `LiveOpsFirebase` | library | Store + `FirebaseRemoteConfig` |
  | `LiveOpsTesting` | library | Store |
  | `liveops` | executable | Core |

- [x] Declare the dependency `firebase-ios-sdk` with the range **`"12.17.0"..<"13.0.0"`**, not an exact version. Each app keeps its own exact pin (Boltfall 12.17.0, the others 12.18.0) and SPM unifies them.
- [x] Use the URL `https://github.com/firebase/firebase-ios-sdk`, exactly as the apps spell it, so SPM treats it as the same package.

**Done when**
- [x] `swift build --target LiveOpsCore` passes on macOS
- [x] `xcodebuild build` passes for LiveOpsCore on the iOS Simulator and watchOS Simulator, and for LiveOpsFirebase on the iOS Simulator
- [x] Resolving the package without building LiveOpsFirebase doesn't force a Firebase build for Core-only consumers (StreakFlame's watch and widgets). This behaviour is checked and recorded.
  > Recorded 2026-09-26: SwiftPM resolves and downloads the whole Firebase graph for every consumer. On macOS and watchOS no Firebase object is compiled (checked in `.build` and the watchsimulator products). On the iOS Simulator `FirebaseRemoteConfig` and its dependencies compile. A compile-time `#error` in the transport catches a broken condition.
- [x] OpenSpec change `add-liveopskit` opened, with proposal, design, 4 capability specs and tasks; `openspec validate --strict` passes

## [x] Section 2 — LiveOpsCore: keys and strict parsing

**Goal.** Rule #3 (naming) and rule #4 (strict, per-key parsing), shared by every app.

- [x] `LiveOpsKind`: a `String`-backed, `ExpressibleByStringLiteral` struct with common constants (`.event`, `.feature`, `.ad`, `.promo`, `.season`, `.offer`, `.collection`). Apps can add their own kinds, because the five apps use seven kinds between them.
- [x] `LiveOpsKey`:
  - `name(_ kind:, id:, field:)` → `<kind>_<sanitised id>_<field>`
  - `sanitise` → any character outside `[a-zA-Z0-9_]` becomes `_`
  - `isValid` → `^[a-zA-Z][a-zA-Z0-9_]*$`
  - `snakeCase`, Boltfall's helper
- [x] `LiveOpsParse`:
  - `bool`: accepts true/1/yes and false/0/no, case-insensitive and trimmed; anything else is `nil`
  - `int(_:in:)`: out of range is `nil`, never clamped
  - `instant`: ISO-8601 internet date-time with offset (S/L/B)
  - `day`: `LiveOpsDay` (H/W)
  - `instantString` / `dayString` for the tooling
- [x] `LiveOpsDay`: a strict `YYYY-MM-DD` calendar day, validated by a UTC round trip (so 2026-02-30 is rejected), `Comparable`, `Codable`. Huefall's `LocalDate` and Wordfell's `LiveOpsDay` map onto it in their own adoption plans.
- [x] Tests for every parser: valid input, whitespace, case, empty, garbage, bounds edges, invalid calendar days, offsets

**Done when**
- [x] Every function above has tests, covering each case in the "strict parsers" comments across the five repos
- [x] `LiveOpsCore` imports only Foundation

## [x] Section 3 — LiveOpsCore: parameters and readings

**Goal.** One description of "a parameter this build reads", used by apps, tests and the CLI.

- [x] `LiveOpsParameter`: `name`, `type` (`.instant`, `.day`, `.bool`, `.int(ClosedRange<Int>)`) and `bundled` (spelled the way the console spells it). Its JSON coding lives with the manifest (Section 9), so there is one schema.
- [x] `Reading`: `.unset`, `.applied(String)`, `.malformed`, `.outOfRange(ClosedRange<Int>)`. The last case comes from Huefall and Wordfell, so the tooling can tell "not a number" apart from "outside the bounds". Apps still treat both as malformed.
- [x] `read(_ raw: String?) -> Reading`
- [x] Key-list helpers: a stable, de-duplicated `keys` list from `[LiveOpsParameter]`, and validation that every name is `isValid` and at most 256 characters

**Done when**
- [x] A table-driven test covers every reading for every value type

## [ ] Section 4 — LiveOpsCore: resolution

**Goal.** Rules #1, #2, #4, #7 and #12 as pure, generic functions.

- [ ] **4.1 Compare edge-case behaviour across the five apps first.** Write `Docs/semantics.md`, a table of how each app handles:
  - end before start;
  - start-only or end-only overrides;
  - `enabled=true` on an item that is off in the bundle;
  - an override for an unknown id;
  - an empty string;
  - the "now" boundary: is the end inclusive or exclusive?

  The kit follows Lineburst. Any real difference gets an explicit parameter; nothing is changed silently.
- [ ] `protocol LiveOpsSwitch: Sendable { var parameterName: String { get } }` and
  `LiveOpsResolve.isEnabled(key:bundled:values:)` → `bundled && bool(values[key]) != false`, with a protocol convenience on top. The string-key form covers Wordfell's id-based features.
- [ ] `protocol LiveOpsNumber: Sendable { parameterName; bundled; bounds }` and `value(_:values:)`. Out of range falls back to the bundled value.
- [ ] `LiveOpsWindow<T: Comparable & Sendable>`, `LiveOpsWindowOverride<T>` (`start?`, `end?`, `enabled?`) and `Phase` (`upcoming`, `live`, `over`)
  - `windowOverride(kind:id:values:parse:)`: each field is parsed on its own, and only known ids are read
  - `effective(bundled:override:) -> LiveOpsWindow<T>?`: `nil` means disabled
  - `phase(of:at:)`: the time is always injected
- [ ] Nothing in Core reads the clock, `ProcessInfo` or `UserDefaults`

**Done when**
- [ ] `Docs/semantics.md` is written and every row has a test
- [ ] The resolution functions cover what the five apps do: S events and promos, L events, features and placements, B events and ad policy, H seasons, W collections and features. This is checked against `Docs/migration.md` (Section 11).

## [ ] Section 5 — LiveOpsStore: holder and fetch policy

**Goal.** Rules #1 (last activation applies, including offline), #5 (fetch policy) and #6 (no fetch in synthetic runs).

- [ ] `@MainActor protocol LiveOpsProviding: AnyObject { var current: LiveOpsValues { get }; func fetch(onActivated: @escaping @MainActor () -> Void) }`
- [ ] `@Observable @MainActor final class LiveOpsStore`:
  - `values`, `attach(provider:)`, `fetch()`, `apply(values:)`
  - a single `onChange` closure, as in all five apps (design decision 8)
  - it is **not** a singleton; each app keeps its own `shared`
- [ ] `LiveOpsGate.shouldFetch(arguments:environment:isTestHost:blockedArguments:blockedEnvironment:blockedPrefixes:)`
- [ ] `LiveOpsGate.isTestHost`: true when an `XCTestCase` class exists **or** `XCTestConfigurationFilePath` is set (the union of the five apps' checks)
- [ ] The fetch never blocks and never surfaces an error. Failures go to an injected `log: (String) -> Void`.

**Done when**
- [ ] Tests with a fake provider cover:
  - bundled values before the first activation;
  - activation then apply;
  - observer order;
  - attaching twice;
  - a fetch without a provider;
  - every combination of gate inputs

## [ ] Section 6 — LiveOpsFirebase: transport

**Goal.** Rule #8: one transport, and it's the only `import FirebaseRemoteConfig`.

- [ ] `FirebaseLiveOpsProvider: LiveOpsProviding`, created with `static func make(keys: [String], configureIfNeeded: Bool, log:) -> Self?`. It returns `nil` when Firebase can't be configured (no plist), and apps then run on bundled values.
- [ ] `current` reads **only** the given keys, and only values with `source == .remote` that are non-empty (rule #4: unset means no override).
- [ ] `fetchAndActivate` uses the SDK's default minimum interval, on the main actor, and never throws to the caller
- [ ] Wrapped in `#if canImport(FirebaseRemoteConfig)` (Boltfall and Wordfell do this), so Core-only consumers compile
- [ ] Keep the doc comments the five copies share ("Deliberately dumb", "Console-set values only")

**Done when**
- [ ] It builds for the iOS Simulator
- [ ] `check-boundary.sh` run on the kit finds exactly one importer
- [ ] Manual smoke test, **checked only, no console writes**: a scratch app with a real plist reads an existing console value. Done in the Lineburst plan if a plist is needed; noted here as deferred.

## [ ] Section 7 — LiveOpsTesting

**Goal.** App wiring tests stop hand-writing fakes.

- [ ] `MemoryLiveOpsProvider`: set values, trigger or suppress activation, count fetches
- [ ] Bundle the Section 8 fixtures as resources (`Sources/LiveOps/Testing/Fixtures/`) so apps' tests can load the same files
- [ ] Fixture loading: turn a Remote Config template JSON (`firebase remoteconfig:get` format) into `LiveOpsValues`

**Done when**
- [ ] The kit's own Store tests use it
- [ ] It isn't linked by any non-test target (documented in the README)

## [ ] Section 8 — Conformance suite and golden fixtures

**Goal.** Prove the kit matches all five apps before any app touches it.

- [ ] Port the **generic** tests from all five repos into Swift Testing, each tagged with where it came from:
  - S: `LiveOpsResolutionTests` 18, `LiveOpsTests` 10
  - L: 19 + 9
  - B: 30 + 9
  - H: 18 + 9 (XCTest, converted)
  - W: 36 + part of the 22 wiring tests

  Remove duplicates; wiring and catalogue tests stay in the apps.
- [ ] `Sources/LiveOps/Testing/Fixtures/`: about 10 Remote Config templates covering empty, all-unset, typos, out-of-range values, windows moved, shortened and disabled, and unknown ids. Each has an `expected.json` with the readings and effective values.
- [ ] Each app's adoption plan will re-run these fixtures against **the app's current resolver** before migrating. That is the proof that behaviour doesn't change.

**Done when**
- [ ] About 60 or more tests are green
- [ ] Line coverage of LiveOpsCore and LiveOpsStore is at least 90%, via `swift test --enable-code-coverage`

## [ ] Section 9 — `liveops` CLI

**Goal.** Replace five near-copies of `run.sh` + `main.swift` with one generic tool. Today each app's CLI compiles the app's own sources. The kit's CLI reads a **manifest** instead.

- [ ] `Docs/manifest.md`: the `liveops-manifest.json` v1 schema:
  - parameters (name, type, bundled, bounds);
  - windows (kind, id, bundled start and end);
  - an optional In-App Event reference.

  Each app will generate this file from a unit test, as part of its adoption plan.
- [ ] `liveops values --manifest <file> --template <file>` prints a table of name, type, bundled value, console value, reading and effective value
- [ ] `liveops check-inapp-events --manifest <file> --template <file> --app-events <file>` exits 1 when an In-App Event's dates don't match the effective window (rule #11)
- [ ] `Scripts/liveops.sh --project <firebase-project> --app-id <asc-id> --manifest <file> <command>`:
  - fetches the template with `firebase remoteconfig:get` (read-only);
  - fetches app events with `GET /v1/apps/<id>/appEvents`, using a token from the existing local `~/.appstoreconnect/asc_token.rb`, which is never copied into the repo;
  - then runs the CLI.
- [ ] Neither the CLI nor the script can write to a console

**Done when**
- [ ] CLI tests pass against the Section 8 fixtures
- [ ] `--help` documents every flag, and the README shows one example run

## [ ] Section 10 — SDK boundary check

**Goal.** One script replaces S's and L's shell checks and B's, H's and W's source-scanning tests.

- [ ] `Scripts/check-boundary.sh <source-dir>... [--module FirebaseRemoteConfig]...` fails if any Swift file under the given directories imports a listed module. For apps the expected count is **zero**, since the kit is now the importer.
- [ ] Self-test against fixture folders: one clean, one violating

**Done when**
- [ ] The script and its self-test pass and are included in `ci-local.sh`

## [ ] Section 11 — Documentation and OpenSpec

- [ ] `Docs/live-ops-rule.md`: the canonical 12-point rule, merged from the five CLAUDE.md files. App CLAUDE.md files will link to it in their adoption plans.
- [ ] `Docs/migration.md`: for **each of the five apps**, a table mapping its current type or function to its kit equivalent, what stays in the app, the tests that move and the tests that stay. This is the input to every adoption plan.
- [ ] `README.md`:
  - install snippets for XcodeGen, both local `path:` and `url:` + `exactVersion:`;
  - a 20-line quick start;
  - a product table and the platform matrix
- [ ] `CHANGELOG.md` with an Unreleased section
- [ ] OpenSpec change `add-liveopskit` (opened in Section 1) with four capabilities: `live-ops-core`, `live-ops-store`, `live-ops-firebase` and `live-ops-tooling`. It is archived in Section 13, which syncs `openspec/specs/`. MUST or SHALL goes on the first line of each requirement body.

**Done when**
- [ ] `openspec validate --all` passes
- [ ] `Docs/migration.md` has a filled section for S, L, B, H and W

## [ ] Section 12 — The local gate

- [ ] `Scripts/ci-local.sh`:
  1. `swiftlint --strict`
  2. `swift test`
  3. `xcodebuild build` for LiveOpsCore and LiveOpsStore on the iOS and watchOS Simulators, and LiveOpsFirebase on the iOS Simulator
  4. `check-boundary.sh` self-test
  5. `openspec validate --all`
- [ ] No GitHub workflow (Asgar, 2026-09-26). `ci-local.sh` runs before every push.

**Done when**
- [ ] `ci-local.sh` passes locally

## [ ] Section 13 — Consumption check and tag 0.1.0

**Goal.** Prove an XcodeGen app can use the kit **by URL and tag**, alongside an exact Firebase pin, before Lineburst touches it.

- [ ] `Examples/ConsumerCheck/`: a minimal XcodeGen iOS app, with no plist, that depends on FallKit by `url:` + `exactVersion:` of a release candidate tag. It builds twice:
  - with `firebase-ios-sdk` pinned exactly to **12.18.0**;
  - with it pinned exactly to **12.17.0** (Boltfall's pin).
- [ ] It also builds a watchOS target that uses LiveOpsCore only
- [ ] Update `CHANGELOG.md` and tag `0.1.0` (after Asgar's queue #5), then publish the GitHub release

**Done when**
- [ ] Both Firebase pins resolve and build
- [ ] The watchOS target builds
- [ ] `0.1.0` is tagged and public
- [ ] **Hand-off:** write the Lineburst adoption plan (a separate document, in the Lineburst repo)

---

## Open decisions

| Decision | Recommendation | Why |
|---|---|---|
| License | MIT | Public repo; lets you reuse the code anywhere without friction |
| CI | **No** (decided 2026-09-26) | The local gate runs before every push |
| Kinds as an open string type vs a closed enum | Open string type + constants | The five apps use 7 different kinds |
| Day type | `LiveOpsDay` in the kit; H and W map onto it | Day-granular windows are a deliberate Huefall design (D6) |
| Also support Firebase 11 | No | StreakFlame upgrades before it adopts the kit |

## Effort

About **3–4 working days** for Sections 0–13, most of it in Sections 4, 8 and 9.
