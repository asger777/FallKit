# FallKit — Plan

**One line.** FallKit is a standalone Swift package library for iOS apps. Its first kit, **LiveOpsKit**, gives any app Firebase Remote Config overrides that can move, shorten, extend or switch off what the app ships with, and never create anything new.

**Repo.** https://github.com/asger777/FallKit (public)
**Stack.** Swift Package Manager · swift-tools 6.0 · Swift 6 language mode · iOS 17, watchOS 10, macOS 14 (macOS is only for tests and the CLI)
**Principle.** The kit depends on nothing that uses it. The specs in `openspec/specs/` are the only contract, and consumers adapt to the kit.

---

## How this plan works

- Sections are done in order. `## [ ]` means not done, `## [x]` means done.
- Tests are written with the code. A section is never committed with failing or missing tests.
- The gate before every push is `Scripts/ci-local.sh`. There is no GitHub workflow, by decision.
- Work goes straight to `main` with conventional commits, one commit and push per section. Releases get semver tags (`0.x` may break the API) and a `CHANGELOG.md` entry.
- Public repo: no secrets, keys, team IDs, project IDs, app IDs, account emails or consumer names.

## Queue

| # | Item | Tick |
|---|---|---|
| 1 | Confirm the license. It defaulted to MIT | ☐ confirm |

---

## Done: 0.1.0 (2026-09-27)

| § | Section |
|---|---|
| 0 | Repo bootstrap: license, lint, OpenSpec, CLAUDE.md |
| 1 | `Package.swift`: five products, Firebase linked on iOS only |
| 2 | Keys, kinds, strict parsers, `LiveOpsDay` |
| 3 | Parameters and readings |
| 4 | Resolution: switches, numbers, windows, phases, end and disabled policies |
| 5 | `LiveOpsStore` and `LiveOpsGate` |
| 6 | `FirebaseLiveOpsProvider` |
| 7 | `LiveOpsTesting` |
| 8 | Conformance suite and golden fixtures |
| 9 | `liveops` CLI, `Scripts/liveops.sh`, manifest |
| 10 | `check-boundary.sh` |
| 11 | Docs |
| 12 | The local gate |
| 13 | Consumption check, tag `0.1.0` |

---

## 0.2.0: standalone

The kit's text, sample data, one constant, one gate rule and its shipped fixtures still used the vocabulary of the code it was first extracted from. 0.2.0 removes all of it. OpenSpec change: `make-kit-standalone`.

## [x] Section 14 — Plan

- [x] OpenSpec change `make-kit-standalone`: proposal, design, spec deltas, tasks
- [x] This plan, rewritten without consumer references

**Done when**
- [x] `openspec validate make-kit-standalone --strict` passes

## [x] Section 15 — Neutral public API

- [x] `LiveOpsKind`: constants for the rule's kinds only (`event`, `season`, `feature`, `ad`, `offer`, `promo`); any other kind is a literal
- [x] `LiveOpsGate.Policy`: `blockedFlags` replaced by `blockedEnvironment: [String: String]`, matching exact values
- [x] Every doc comment in `Sources/` and `Package.swift` describes behaviour, not consumers

**Done when**
- [x] No consumer word in `Sources/`, `Package.swift` or `Examples/`, apart from the fixture files, which move in Section 16
- [x] The gate passes

## [x] Section 16 — Testing product

- [x] `LiveOpsGolden.mismatches(manifest:values:expected:)` and `LiveOpsGoldenExpectation` / `LiveOpsGoldenProbe` in `LiveOpsTesting`
- [x] The kit's fixtures move to a non-product `LiveOpsTestFixtures` target (`Tests/LiveOps/Fixtures`), with neutral sample ids
- [x] Probes re-written by hand for the new ids; reports re-recorded and reviewed
  > The rename is mechanical (only ids changed; dates, values and phases did not). As proof, the old expected files with the same rename applied are identical to the re-recorded ones.

**Done when**
- [x] `LiveOpsTesting` ships no fixture files
- [x] Every probe and report passes through `LiveOpsGolden`

## [ ] Section 17 — Tests

- [ ] Neutral sample data everywhere
- [ ] No origin tags and no "from app X" comments

**Done when**
- [ ] No consumer word in `Tests/`
- [ ] Coverage of Core and Store stays at or above 90%

## [ ] Section 18 — Docs

- [ ] `Docs/behaviour.md` describes what the kit does: windows, parsing, readings, gate, test hosts
- [ ] Delete `Docs/migration.md`, `Docs/semantics.md` and the archived `0.1.0` change
- [ ] Rewrite `README.md` (a new-app quick start and recommended defaults), `CLAUDE.md` (the specs are the contract), the OpenSpec config and spec purposes, `Docs/live-ops-rule.md`, `Docs/manifest.md` and `CHANGELOG.md`

**Done when**
- [ ] No consumer word in `Docs/`, `openspec/` or the top-level files

## [ ] Section 19 — Guard and release

- [ ] `ci-local.sh` fails on any word from the untracked `.fallkit-forbidden-words` file, and says so when the file is absent
- [ ] Full gate, archive `make-kit-standalone`, tag `0.2.0`, GitHub release
- [ ] `Examples/ConsumerCheck` builds against `0.2.0`

**Done when**
- [ ] `0.2.0` is tagged and public, and the gate, including the guard, is green
