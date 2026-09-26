# live-ops-core Specification

## Purpose
Pure live-ops logic shared by the five apps: console key naming, strict parsing, parameter readings, and the resolution of switches, bounded numbers and date windows. It has no SDK and no ambient state, so every result is a tested function of its inputs.

## Requirements
### Requirement: Parameter keys follow kind, id and field
`LiveOpsKey.name(kind, id:, field:)` MUST return `<kind>_<sanitised id>_<field>`, where sanitising replaces every Unicode scalar outside `[a-zA-Z0-9_]` with one `_` and keeps letter case.

#### Scenario: A hyphenated event id
- **WHEN** the name is built for kind `event`, id `harvest-moon`, field `start`
- **THEN** it is `event_harvest_moon_start`

#### Scenario: Case and multi-byte characters
- **WHEN** `pt-BR`, `winter moon/2026.b` and `a✨b` are sanitised
- **THEN** they become `pt_BR`, `winter_moon_2026_b` and `a_b`

### Requirement: Key validity matches the console
`LiveOpsKey.isValid` MUST accept a key only when it matches `^[a-zA-Z][a-zA-Z0-9_]*$`.

#### Scenario: Invalid keys
- **WHEN** `1feature`, `event_new-year_end` or an empty string is checked
- **THEN** each is invalid, and `feature_icloud_sync_enabled` is valid

### Requirement: Snake-case helper for camel-case ids
`LiveOpsKey.snakeCase` MUST insert `_` before every uppercase letter except the first character, lowercase the result, then sanitise it.

#### Scenario: Placement ids
- **WHEN** `rewardedCoinDoubler`, `RewardedFuse` and `interstitial` are converted
- **THEN** they become `rewarded_coin_doubler`, `rewarded_fuse` and `interstitial`

### Requirement: Strict boolean parsing
`LiveOpsParse.bool` MUST trim whitespace and newlines, compare case-insensitively, and return `true` for `true`, `1` or `yes`, `false` for `false`, `0` or `no`, and `nil` for anything else.

#### Scenario: Accepted and rejected spellings
- **WHEN** ` Yes `, `NO\n`, `on`, `off`, `2`, an empty string and `nil` are parsed
- **THEN** the results are `true`, `false`, and `nil` for the rest

### Requirement: Integers are whole and inside bounds
`LiveOpsParse.int(_:in:)` MUST trim the text, parse a base-10 `Int`, and return `nil` when the text is not a whole number or the value is outside the bounds. It MUST never clamp.

#### Scenario: Bounds 1...10
- **WHEN** ` 10 `, `1`, `0`, `11`, `2.5`, `three`, `5 completions` and `1e1` are parsed
- **THEN** the first two give 10 and 1, and every other value gives `nil`

### Requirement: Instants are ISO-8601 internet date-times
`LiveOpsParse.instant` MUST accept only an ISO-8601 internet date-time with a time-zone designator and reject date-only strings, epoch digits and other text. `LiveOpsParse.string(instant:)` MUST spell an instant in UTC with `Z`.

#### Scenario: Offsets are normalised
- **WHEN** `2026-10-01T04:00:00+04:00` is parsed and spelled
- **THEN** the result equals the instant of `2026-10-01T00:00:00Z` and spells as that string

#### Scenario: Rejected forms
- **WHEN** `2026-10-01`, `1790812800` and `next tuesday` are parsed
- **THEN** each gives `nil`

### Requirement: Days are strict calendar days
`LiveOpsParse.day` MUST accept exactly `YYYY-MM-DD` (4-2-2 digits, after trimming) that names a real Gregorian date, and return a `Comparable` `LiveOpsDay`.

#### Scenario: Invalid days
- **WHEN** `2026-02-30`, `2026-13-01`, `2026-10-2`, `20261024`, `30/11/2026` and `2026-10-24T00:00:00Z` are parsed
- **THEN** each gives `nil`, and ` 2026-10-24\n` gives the day `2026-10-24`

### Requirement: A day can be derived from a date and a calendar
`LiveOpsDay(date:calendar:)` MUST return the calendar day that contains the date in that calendar's time zone, without reading the clock itself.

#### Scenario: Time zone decides the day
- **WHEN** the instant `2026-10-24T22:30:00Z` is converted with a Gregorian calendar in `Asia/Baku` (UTC+4)
- **THEN** the day is `2026-10-25`

### Requirement: Parameter readings classify every console value
`LiveOpsParameter.read(_:)` MUST return `.unset` for `nil`, `.applied(normalised)` for a valid value, `.outOfRange(bounds)` for a whole number outside an integer parameter's bounds, and `.malformed` otherwise. `Reading.isMalformed` MUST be true for both `.malformed` and `.outOfRange`.

#### Scenario: Integer parameter 1...5
- **WHEN** `nil`, `2`, `9` and `two` are read
- **THEN** they give `.unset`, `.applied("2")`, `.outOfRange(1...5)` and `.malformed`

#### Scenario: Normalised spellings
- **WHEN** a bool parameter reads `NO` and an instant parameter reads `2027-01-01T04:00:00+04:00`
- **THEN** they give `.applied("false")` and `.applied("2027-01-01T00:00:00Z")`

### Requirement: Switches only switch off
`LiveOpsResolve.isEnabled(key:bundled:values:)` MUST return `bundled && bool(values[key]) != false`. A console value MUST never switch on something that is off in the bundle.

#### Scenario: Off, unset, malformed and on
- **WHEN** the bundle is on and the console value is `false`, absent, `maybe` or `true`
- **THEN** only `false` switches it off

#### Scenario: Bundled off stays off
- **WHEN** the bundle is off and the console value is `true`
- **THEN** the switch is off

### Requirement: Numbers fall back to the bundled value
`LiveOpsResolve.value(_:values:)` for a `LiveOpsNumber` MUST return the console value when `int(_:in: bounds)` accepts it, and the bundled value otherwise.

#### Scenario: Out of range is not clamped
- **WHEN** bounds are 1...5, the bundled value is 3, and the console holds `0`, `6`, `2.5` or `5`
- **THEN** the results are 3, 3, 3 and 5

### Requirement: Window overrides are read per field for known ids
`LiveOpsResolve.windowOverride(kind:id:values:parse:)` MUST read `start`, `end` and `enabled` independently, so a malformed field is dropped without affecting its siblings. `windowOverrides(kind:ids:values:parse:)` MUST read only the given ids and omit empty overrides.

#### Scenario: A malformed sibling
- **WHEN** `start` is `next tuesday`, `enabled` is `maybe` and `end` is valid
- **THEN** the override has only `end`

#### Scenario: Unknown ids are never read
- **WHEN** the console holds keys for an id that is not in `ids`
- **THEN** the result has no entry for it

### Requirement: Effective window
`LiveOpsResolve.effective(bundled:override:)` MUST return `nil` when the override's `enabled` is `false`, and otherwise the bundled window with each overridden bound replaced independently.

#### Scenario: Start only
- **WHEN** only `start` is overridden
- **THEN** the start moves and the bundled end stays

### Requirement: Window phase follows the end policy
`LiveOpsResolve.phase(of:at:end:)` MUST return `.upcoming` when `at < start`, `.over` when `at >= end` under `.exclusive` or `at > end` under `.inclusive`, and `.live` otherwise.

#### Scenario: Exclusive instants
- **WHEN** the window is `[start, end)` and the policy is `.exclusive`
- **THEN** `start` is live, `end` is over and `start - 1s` is upcoming

#### Scenario: Inclusive days
- **WHEN** the window is `2026-10-24 ... 2026-11-06` and the policy is `.inclusive`
- **THEN** 2026-11-06 is live and 2026-11-07 is over

#### Scenario: Inverted windows are never live
- **WHEN** the end is before the start
- **THEN** no moment reads `.live` under either policy

### Requirement: What disabled means is chosen by the caller
`LiveOpsResolve.phase(bundled:override:at:end:whenDisabled:)` MUST return `nil` for a disabled window under `.removed`. Under `.closed` it MUST return `.upcoming` before the effective start and `.over` from the start on.

#### Scenario: Closed rather than removed
- **WHEN** a disabled window starts on 2026-10-15 and the policy is `.closed`
- **THEN** 2026-10-14 is upcoming and 2026-10-20 is over

### Requirement: The core is pure
`LiveOpsCore` MUST import only Foundation and MUST NOT read the clock, `ProcessInfo`, `UserDefaults` or the file system.

#### Scenario: Source scan
- **WHEN** the sources of `Sources/LiveOps/Core` are scanned
- **THEN** they import only Foundation and contain no `Date()`, `ProcessInfo`, `UserDefaults` or `FileManager`

