/// Parameter naming (rule #3): `<kind>_<id>_<field>`.
public enum LiveOpsKey {
    /// `<kind>_<sanitised id>_<field>`, for example `event_harvest_moon_start`.
    public static func name(_ kind: LiveOpsKind, id: String, field: String) -> String {
        "\(kind.rawValue)_\(sanitise(id))_\(field)"
    }

    /// Remote Config rejects any key with a character outside `[a-zA-Z0-9_]`
    /// (the console says INVALID_KEY), which hyphenated bundled ids would
    /// otherwise trip: `harvest-moon` → `harvest_moon`. One `_` per Unicode
    /// scalar; letter case is kept (`pt-BR` → `pt_BR`).
    public static func sanitise(_ id: String) -> String {
        String(id.unicodeScalars.map { scalar -> Character in
            switch scalar {
            case "a"..."z", "A"..."Z", "0"..."9", "_": Character(scalar)
            default: "_"
            }
        })
    }

    /// camelCase → snake_case, then sanitised: `rewardedCoinDoubler` →
    /// `rewarded_coin_doubler`, so placement keys read like the rest.
    public static func snakeCase(_ id: String) -> String {
        var out = ""
        for scalar in id.unicodeScalars {
            if ("A"..."Z").contains(scalar) {
                if !out.isEmpty { out.append("_") }
                out.append(Character(scalar).lowercased())
            } else {
                out.append(Character(scalar))
            }
        }
        return sanitise(out)
    }

    /// What the console accepts as a parameter key.
    public static func isValid(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, isLetter(first) else { return false }
        return key.unicodeScalars.allSatisfy { isLetter($0) || ("0"..."9").contains($0) || $0 == "_" }
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}
