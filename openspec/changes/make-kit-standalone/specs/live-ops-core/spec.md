## MODIFIED Requirements

### Requirement: Parameter keys follow kind, id and field
`LiveOpsKey.name(kind, id:, field:)` MUST return `<kind>_<sanitised id>_<field>`, where sanitising replaces every Unicode scalar outside `[a-zA-Z0-9_]` with one `_` and keeps letter case.

#### Scenario: A hyphenated event id
- **WHEN** the name is built for kind `event`, id `spring-sale`, field `start`
- **THEN** it is `event_spring_sale_start`

#### Scenario: Case and multi-byte characters
- **WHEN** `pt-BR`, `winter moon/2026.b` and `a✨b` are sanitised
- **THEN** they become `pt_BR`, `winter_moon_2026_b` and `a_b`

### Requirement: Key validity matches the console
`LiveOpsKey.isValid` MUST accept a key only when it matches `^[a-zA-Z][a-zA-Z0-9_]*$`.

#### Scenario: Invalid keys
- **WHEN** `1feature`, `event_spring-sale_end` or an empty string is checked
- **THEN** each is invalid, and `feature_dark_mode_enabled` is valid

## ADDED Requirements

### Requirement: Kind constants are the rule's kinds
`LiveOpsKind` MUST offer constants only for `event`, `season`, `feature`, `ad`, `offer` and `promo`, and MUST accept any other kind as a string literal.

#### Scenario: A custom kind
- **WHEN** an app names a parameter with the literal kind `collection`
- **THEN** the key is `collection_<id>_<field>` and no constant is needed
