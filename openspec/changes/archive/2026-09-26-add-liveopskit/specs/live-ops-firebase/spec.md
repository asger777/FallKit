## ADDED Requirements

### Requirement: Only console-set values count
`FirebaseLiveOpsProvider.current` MUST contain only the keys it was created with, and only values whose source is `.remote` and whose string value is non-empty.

#### Scenario: SDK defaults are ignored
- **WHEN** a key has only the SDK's static default
- **THEN** it is absent from `current`

### Requirement: Fetch never blocks and never fails loudly
`fetch(onActivated:)` MUST call `fetchAndActivate` with the SDK's default minimum interval, call `onActivated` on the main actor after a successful fetch, never call it after `status == .error`, and report failures only through the injected log closure.

#### Scenario: Error status
- **WHEN** the SDK reports `.error`
- **THEN** `onActivated` is not called and one log line is written

### Requirement: The provider exists only when Firebase is ready
`FirebaseLiveOpsProvider.make(keys:configure:log:)` MUST return `nil` when the `configure` closure returns false. The standard closure MUST return true for an existing `FirebaseApp`, configure Firebase when `GoogleService-Info.plist` is bundled, and return false otherwise.

#### Scenario: No plist
- **WHEN** no Firebase app exists and no plist is bundled
- **THEN** `make` returns `nil` and the app runs on bundled values

### Requirement: One importer of Remote Config
The repo MUST contain exactly one Swift file that imports `FirebaseRemoteConfig`, at `Sources/LiveOps/Firebase/FirebaseLiveOpsProvider.swift`, and that file MUST compile on platforms without the module.

#### Scenario: Boundary check
- **WHEN** `check-boundary.sh` scans the repo for `FirebaseRemoteConfig`
- **THEN** it finds exactly that one file
