## ADDED Requirements

### Requirement: Bundled values apply until an activation
`LiveOpsStore` MUST start with the values it is created with (empty by default), so that every resolution falls back to the bundle until a provider delivers an activation.

#### Scenario: No provider
- **WHEN** a store is created and no provider is attached
- **THEN** `values` is empty and `hasProvider` is false

### Requirement: Attach applies the cache at once without notifying
`attach(provider:)` MUST set `values` to `provider.current` synchronously, start exactly one fetch, and MUST NOT call `onChange`.

#### Scenario: Cached override on launch
- **WHEN** a provider whose cache holds `feature_x_enabled=false` is attached
- **THEN** `values` holds it immediately, the provider counts one fetch, and `onChange` has not run

### Requirement: Only a changing activation notifies
After an activation the store MUST replace `values` with `provider.current` and call `onChange` exactly once, and only when the new values differ from the old ones.

#### Scenario: Same, new, same, removed
- **WHEN** activations deliver the same values, then new values, then the same new values again, then `[:]`
- **THEN** `onChange` runs twice in total, and the last activation returns every item to the bundle

### Requirement: Apply is the activation seam
`apply(values:)` MUST behave exactly like an activation that delivered those values.

#### Scenario: Tests drive activations
- **WHEN** `apply(values:)` is called twice with the same new values
- **THEN** `onChange` runs once

### Requirement: Fetch without a provider does nothing
`fetch()` MUST be a no-op when no provider is attached, and otherwise ask the provider to fetch once per call.

#### Scenario: Foreground fetch
- **WHEN** a provider is attached and the app calls `fetch()` on foreground
- **THEN** the provider has counted two fetches

### Requirement: No fetch in synthetic runs
`LiveOpsGate.shouldFetch(_:policy:)` MUST return false for a test host, a screenshot run, any blocked argument, any argument with a blocked prefix, and any blocked environment flag set to `1`, and true otherwise.

#### Scenario: Prefix rule
- **WHEN** the policy blocks the prefix `-debug.` and the launch has `-debug.level`
- **THEN** the gate is false, and a plain launch with `-AppleLanguages` is true

### Requirement: Test-host detection is the union of the apps' checks
`LiveOpsGate.isTestHost(classExists:environment:)` MUST be true when the `XCTestCase` class exists or `XCTestConfigurationFilePath` is set.

#### Scenario: Environment only
- **WHEN** the class is absent and the environment variable is set
- **THEN** it is a test host
