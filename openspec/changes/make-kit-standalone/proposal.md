## Why

FallKit's code has no dependency on any consumer. But its text, sample data, one public constant, one gate rule and its test fixtures were written in terms of the codebases it was first extracted from, and one project rule made those codebases the authority over the kit's behaviour. A library must be defined only by its own contract, so that any app, including one that does not exist yet, can adopt it on equal terms.

## What Changes

- **BREAKING** `LiveOpsKind`: the constants `.ads` and `.collection` are removed. The kit names only the kinds the live-ops rule names (`event`, `season`, `feature`, `ad`, `offer`, `promo`); every other kind is a string literal.
- **BREAKING** `LiveOpsGate.Policy.blockedFlags` is replaced by `blockedEnvironment: [String: String]`, which blocks on an exact environment key and value. An argument form of the same switch goes in `blockedArguments`.
- **BREAKING** `LiveOpsTesting` no longer ships fixtures. It gains `LiveOpsGolden`, a generic check that runs an app's own manifest, console template and expectations. The kit's own conformance fixtures move to a test-only target that is not a product.
- The specs in `openspec/specs/` become the only authority over behaviour. Documentation describes the kit's behaviour, with no comparison to any consumer.
- The sample data in the tests and fixtures becomes neutral.
- The local gate fails when a word from an optional, untracked `.fallkit-forbidden-words` file appears in the repository.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `live-ops-core`: neutral key scenarios; the kind constants are defined by the rule.
- `live-ops-store`: exact-value environment blocking; test-host detection restated without consumers.
- `live-ops-tooling`: neutral manifest scenario; shipped fixtures replaced by the golden check; the repository names no consumer.

## Impact

- Public API: three breaking changes, released as `0.2.0`. Nothing consumes `0.1.0` yet.
- Behaviour: resolution, parsing, the store and the transport are unchanged.
- History: git history and the `0.1.0` tag are left as they are.
