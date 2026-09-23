import Foundation

/// The subset of `UserDefaults` the app persists through, so demo mode can swap in memory.
public protocol KeyValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueStore {}

public final class InMemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func object(forKey key: String) -> Any? { values[key] }

    public func set(_ value: Any?, forKey key: String) { values[key] = value }
}
