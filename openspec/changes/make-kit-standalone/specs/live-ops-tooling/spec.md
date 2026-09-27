## MODIFIED Requirements

### Requirement: The manifest describes what an app reads
`LiveOpsManifest` (JSON, `schemaVersion: 1`) MUST list every parameter (name, type, bundled value, bounds) and every window (kind, id, bundled start and end, value type, end policy, optional In-App Event reference), and decoding MUST reject invalid parameter names and unknown schema versions.

#### Scenario: Invalid name
- **WHEN** a manifest lists `event_spring-sale_end`
- **THEN** decoding fails and names the bad key

## REMOVED Requirements

### Requirement: Golden fixtures are shared with the apps
**Reason**: Shipped fixtures served particular consumers' migrations. A library ships tools, not other projects' data.
**Migration**: Use `LiveOpsGolden.mismatches(manifest:values:expected:)` with the app's own manifest, templates and `LiveOpsGoldenExpectation` files.

## ADDED Requirements

### Requirement: Golden checks for an app's own fixtures
`LiveOpsGolden.mismatches(manifest:values:expected:)` MUST return one readable line for every probe whose window phase differs from the expectation, and for every report row that differs from a recorded report, and an empty list when everything matches.

#### Scenario: A moved window
- **WHEN** a probe expects `.live` at a moment the console moved outside the window
- **THEN** the result names the window, the moment, and the expected and actual phases

### Requirement: The repository names no consumer
The local gate MUST fail when any tracked file contains a word listed in the untracked `.fallkit-forbidden-words` file, and MUST report when that file is absent.

#### Scenario: A consumer name in a comment
- **WHEN** a source comment contains a word from the list
- **THEN** the gate prints the file and line and fails
