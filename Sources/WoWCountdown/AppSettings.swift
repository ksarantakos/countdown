import Foundation
import CountdownCore

/// Persisted UI state. Backed by an in-memory store in demo mode.
@MainActor
final class AppSettings {
    private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
    }

    var widgetVisible: Bool {
        get { store.object(forKey: "widgetVisible") as? Bool ?? true }
        set { store.set(newValue, forKey: "widgetVisible") }
    }

    var placement: SavedPlacement? {
        get {
            guard let data = store.object(forKey: "widgetPlacement") as? Data else { return nil }
            return try? JSONDecoder().decode(SavedPlacement.self, from: data)
        }
        set {
            store.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "widgetPlacement")
        }
    }
}
