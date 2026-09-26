/// The first part of a parameter name: `<kind>_<id>_<field>`.
///
/// An open set rather than an enum, because the five apps use seven kinds between them.
/// The constants cover the ones in use; an app can add its own with a string literal.
public struct LiveOpsKind: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    /// Seasonal events and their windows (StreakFlame, Lineburst, Boltfall).
    public static let event: LiveOpsKind = "event"
    /// Feature kill switches.
    public static let feature: LiveOpsKind = "feature"
    /// Ad placements and ad policy (Lineburst, Boltfall, Wordfell).
    public static let ad: LiveOpsKind = "ad"
    /// Ad placements and ad policy, plural spelling (Huefall).
    public static let ads: LiveOpsKind = "ads"
    /// Promotions (StreakFlame).
    public static let promo: LiveOpsKind = "promo"
    /// Offers (Huefall, Wordfell).
    public static let offer: LiveOpsKind = "offer"
    /// Seasons with day windows (Huefall).
    public static let season: LiveOpsKind = "season"
    /// Themed collections with day windows (Wordfell).
    public static let collection: LiveOpsKind = "collection"
}
