## MODIFIED Requirements

### Requirement: No fetch in synthetic runs
`LiveOpsGate.shouldFetch(_:policy:)` MUST return false for a test host, a screenshot run, any blocked argument, any argument with a blocked prefix, and any environment variable whose value equals its blocked value, and true otherwise.

#### Scenario: Prefix rule
- **WHEN** the policy blocks the prefix `-debug.` and the launch has `-debug.level`
- **THEN** the gate is false, and a plain launch with `-AppleLanguages` is true

#### Scenario: Exact environment value
- **WHEN** the policy blocks `APP_UITEST=1` and the environment has `APP_UITEST=1`
- **THEN** the gate is false, and `APP_UITEST=0` leaves it true

## RENAMED Requirements

- FROM: `### Requirement: Test-host detection is the union of the apps' checks`
- TO: `### Requirement: Test-host detection covers both XCTest signals`
