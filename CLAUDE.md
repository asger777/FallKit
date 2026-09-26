# FallKit — project rules

Public Swift package repo shared by five iOS apps in `~/Documents/GitHub/OWN`:
StreakFlame (`Streaklet/`), Lineburst (`Blockfall(lineburst)/`, targets named `Blockrise`),
Boltfall, Huefall and Wordfell (`Casual/`). `PLAN.md` is the build plan; tick it as work lands.

## Scope

**Work happens in this repo only.** Never edit an app repo from here. Reading the apps is fine and
expected: they are the reference for every behaviour the kit copies. Each app adopts the kit
through its own plan in its own repo.

## Public repo

Never commit secrets, API keys, `.p8` files, team IDs, Firebase project IDs, App Store app IDs or
account emails. Anything app-specific is passed in as an argument or read from a local file that
is not in the repo (`~/.appstoreconnect/asc_token.rb` for App Store Connect tokens).

## Architecture rules

1. Dependencies point downward: `LiveOpsCore` ← `LiveOpsStore` ← `LiveOpsFirebase` / `LiveOpsTesting`.
   The CLI depends on `LiveOpsCore` only.
2. `LiveOpsCore` imports Foundation only. It never reads the clock, `ProcessInfo`, `UserDefaults`
   or the file system; time and environment are injected. Every function in it is pure and tested.
3. Exactly one file imports `FirebaseRemoteConfig`: `Sources/LiveOps/Firebase/FirebaseLiveOpsProvider.swift`.
   `Scripts/check-boundary.sh` enforces this.
4. The kit never writes to a Firebase console or to App Store Connect. The tooling is read-only.
5. Behaviour must match the five apps. Where they differ, the kit follows Lineburst and exposes
   the difference as an explicit option. `Docs/semantics.md` records every such case.
6. Future kits follow the same shape: `Sources/<Kit>/{Core,Store,<SDK>,Testing}`, one version tag
   for the whole repo, and no shared "utilities" module until two kits need the same thing.

## Workflow

- Straight to `main`, with conventional commits, one section of `PLAN.md` at a time.
- The gate before every push is `Scripts/ci-local.sh` (lint, `swift test`, simulator builds,
  boundary self-test, `openspec validate`). There is no GitHub workflow, by Asgar's decision.
- Tags follow semver: `0.x.y` until an app ships with the kit. Every tag gets a `CHANGELOG.md` entry.
- OpenSpec: put MUST or SHALL on the first line of every requirement body, and give every
  requirement a `#### Scenario:`.
