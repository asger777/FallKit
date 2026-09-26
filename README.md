# FallKit

Swift packages shared by five iOS apps: StreakFlame, Lineburst, Boltfall, Huefall and Wordfell.

> **Status: pre-0.1.** The API is still being built. See [PLAN.md](PLAN.md).

## LiveOpsKit

The live-ops layer: Firebase Remote Config overrides that can move, shorten, extend or switch off
what an app ships with, and never create anything new. The rule the products implement is in
`Docs/live-ops-rule.md`.

| Product | What it is | Imports |
|---|---|---|
| `LiveOpsCore` | Pure keys, parsing and resolution | Foundation |
| `LiveOpsStore` | `@Observable` holder and fetch policy | LiveOpsCore, Observation |
| `LiveOpsFirebase` | The Remote Config transport | LiveOpsStore, FirebaseRemoteConfig (iOS) |
| `LiveOpsTesting` | A fake provider and golden fixtures. **Link it from test targets only.** | LiveOpsStore |
| `liveops` | CLI: print live values, check In-App Event dates | LiveOpsCore |

## License

MIT, see [LICENSE](LICENSE).
