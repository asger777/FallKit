/// The first part of a parameter name: `<kind>_<id>_<field>`.
///
/// An open set rather than an enum. The constants cover the kinds the live-ops
/// rule itself names; any other kind is a string literal (`"collection"`).
public struct LiveOpsKind: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    /// Limited-time events and their windows.
    public static let event: LiveOpsKind = "event"
    /// Seasons and their windows.
    public static let season: LiveOpsKind = "season"
    /// Feature kill switches.
    public static let feature: LiveOpsKind = "feature"
    /// Ad placements and ad policy.
    public static let ad: LiveOpsKind = "ad"
    /// Offers and sales.
    public static let offer: LiveOpsKind = "offer"
    /// Promotions.
    public static let promo: LiveOpsKind = "promo"
}
