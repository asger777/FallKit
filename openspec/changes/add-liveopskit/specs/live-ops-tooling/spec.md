## ADDED Requirements

### Requirement: The manifest describes what an app reads
`LiveOpsManifest` (JSON, `schemaVersion: 1`) MUST list every parameter (name, type, bundled value, bounds) and every window (kind, id, bundled start and end, value type, end policy, optional In-App Event reference), and decoding MUST reject invalid parameter names and unknown schema versions.

#### Scenario: Invalid name
- **WHEN** a manifest lists `event_harvest-moon_end`
- **THEN** decoding fails and names the bad key

### Requirement: The values command reports every parameter
`liveops values --manifest <file> --template <file>` MUST print, for every manifest parameter, its type, bundled value, console value, reading and effective value, reading only console values from the Remote Config template.

#### Scenario: Out-of-range console value
- **WHEN** the template sets an integer parameter outside its bounds
- **THEN** its reading prints as out of range and its effective value is the bundled one

### Requirement: In-App Event dates match effective windows
`liveops check-inapp-events` MUST exit with status 1, and name each mismatch, when an In-App Event referenced by a window has dates that differ from that window's effective start or end.

#### Scenario: Console moved the end
- **WHEN** the console extends a window's end and the In-App Event still has the bundled end
- **THEN** the command lists that event and exits 1

### Requirement: Tooling is read-only
The `liveops` CLI and `Scripts/liveops.sh` MUST NOT write to a Firebase console or to App Store Connect.

#### Scenario: Source scan
- **WHEN** the CLI and script are scanned for write verbs (`remoteconfig:set`, `deploy`, POST, PATCH, DELETE)
- **THEN** none are present

### Requirement: Golden fixtures are shared with the apps
`LiveOpsTesting` MUST bundle the Remote Config fixture templates, each paired with the expected readings, and load them as `LiveOpsValues`.

#### Scenario: Loading a fixture
- **WHEN** a test loads the fixture `malformed-siblings`
- **THEN** it gets only the console-set values, keyed by parameter name

### Requirement: SDK boundary check
`Scripts/check-boundary.sh` MUST exit non-zero, and list the files, when any Swift file under the given directories imports a listed module.

#### Scenario: A violating app file
- **WHEN** an app file imports `FirebaseRemoteConfig` and the module is listed
- **THEN** the script prints that file and exits 1
