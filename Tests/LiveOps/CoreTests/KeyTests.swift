import LiveOpsCore
import Testing

/// Parameter naming (rule #3). Cases are the union of the five apps' key suites.
@Suite("LiveOpsKey")
struct KeyTests {
    @Test("name is kind_id_field with the id sanitised", arguments: [
        (LiveOpsKind.event, "new-year-2027", "start", "event_new_year_2027_start"),        // S
        (.event, "harvest-moon", "enabled", "event_harvest_moon_enabled"),                 // L
        (.event, "spring2027", "end", "event_spring2027_end"),                             // L
        (.event, "harvest_2026", "end", "event_harvest_2026_end"),                         // B
        (.ad, "interstitial", "min_level", "ad_interstitial_min_level"),                   // B
        (.season, "winter-lights 2027", "enabled", "season_winter_lights_2027_enabled"),   // H
        (.ad, "policy", "quiet_days", "ad_policy_quiet_days"),                             // W
        (.offer, "auto_paywall", "enabled", "offer_auto_paywall_enabled"),                 // W
        ("promo", "starter_shield", "count", "promo_starter_shield_count"),                // S, custom literal
    ])
    func name(kind: LiveOpsKind, id: String, field: String, expected: String) {
        #expect(LiveOpsKey.name(kind, id: id, field: field) == expected)
    }

    @Test("sanitise: one underscore per scalar outside [a-zA-Z0-9_], case kept", arguments: [
        ("harvest-2026", "harvest_2026"),
        ("winter moon/2026.b", "winter_moon_2026_b"),
        ("already_fine_09", "already_fine_09"),
        ("a✨b", "a_b"),
        ("ünïcode-id", "_n_code_id"),
        ("pt-BR", "pt_BR"),
        ("harvest moon.2026", "harvest_moon_2026"),
        ("novruz", "novruz"),
        ("ə.ü", "___"),
    ])
    func sanitise(id: String, expected: String) {
        #expect(LiveOpsKey.sanitise(id) == expected)
    }

    @Test("snakeCase inserts _ before capitals except the first, then sanitises", arguments: [
        ("rewardedCoinDoubler", "rewarded_coin_doubler"),
        ("interstitial", "interstitial"),
        ("RewardedFuse", "rewarded_fuse"),
        ("heartRefill-v2", "heart_refill_v2"),
    ])
    func snakeCase(id: String, expected: String) {
        #expect(LiveOpsKey.snakeCase(id) == expected)
    }

    @Test("isValid matches ^[a-zA-Z][a-zA-Z0-9_]*$", arguments: [
        ("feature_icloud_sync_enabled", true),
        ("collection_halloween_end", true),
        ("a", true),
        ("event_new-year_end", false),
        ("event_harvest-2026_end", false),
        ("1feature", false),
        ("1_starts_with_digit", false),
        ("_leading", false),
        ("collection-halloween", false),
        ("", false),
        ("trailing_newline\n", false),
        ("ümlaut_key", false),
    ])
    func isValid(key: String, valid: Bool) {
        #expect(LiveOpsKey.isValid(key) == valid)
    }

    @Test("every sanitised name is a valid console key")
    func sanitisedNamesAreValid() {
        for id in ["harvest-moon", "ünïcode-id", "2026 spring", "a✨b"] {
            #expect(LiveOpsKey.isValid(LiveOpsKey.name(.event, id: id, field: "start")))
        }
    }
}
