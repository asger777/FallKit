/// The raw console values an app reads, keyed by parameter name.
///
/// Only values set in the console appear here; an unset key is simply absent
/// (rule #4: unset means no override). Every value stays a `String` until a
/// strict parser in ``LiveOpsParse`` reads it for its own key.
public typealias LiveOpsValues = [String: String]
