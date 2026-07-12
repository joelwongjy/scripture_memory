import Foundation
import Combine

/// Persists the user's custom pack ordering and hidden packs (by pack name).
/// Layered on top of the built-in pack list so order/visibility survive launches
/// and apply consistently across Packs, Daily, and Review.
@MainActor
final class PackPreferencesStore: ObservableObject {

    static let shared = PackPreferencesStore()

    @Published private(set) var order:  [String]      = []
    @Published private(set) var hidden: Set<String>   = []

    private let defaults = UserDefaults.standard
    private static let orderKey  = "packs.order.v1"
    private static let hiddenKey = "packs.hidden.v1"

    private init() {
        order  = defaults.stringArray(forKey: Self.orderKey) ?? []
        hidden = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    func isHidden(_ name: String) -> Bool { hidden.contains(name) }

    /// Visible packs (hidden removed) in the user's order.
    func visible(from packs: [Pack]) -> [Pack] {
        let names = PackArranger.visibleNames(order: order, hidden: hidden, all: packs.map(\.name))
        return reorder(packs, by: names)
    }

    /// All packs in the user's order (including hidden) — for the organizer.
    func arranged(from packs: [Pack]) -> [Pack] {
        let names = PackArranger.arrangedNames(order: order, all: packs.map(\.name))
        return reorder(packs, by: names)
    }

    func setHidden(_ name: String, _ isHidden: Bool) {
        if isHidden { hidden.insert(name) } else { hidden.remove(name) }
        defaults.set(Array(hidden), forKey: Self.hiddenKey)
    }

    /// Reorder from an `.onMove` over the currently-arranged pack list.
    func move(arranged packs: [Pack], from source: IndexSet, to destination: Int) {
        let names = PackArranger.movedOrder(arranged: packs.map(\.name), from: source, to: destination)
        order = names
        defaults.set(order, forKey: Self.orderKey)
    }

    /// Restore the default arrangement: natural pack order, nothing hidden.
    func reset() {
        order = []
        hidden = []
        defaults.removeObject(forKey: Self.orderKey)
        defaults.removeObject(forKey: Self.hiddenKey)
    }

    /// Whether anything has been customised (drives the Reset button's enabled state).
    var hasCustomization: Bool { !order.isEmpty || !hidden.isEmpty }

    private func reorder(_ packs: [Pack], by names: [String]) -> [Pack] {
        let byName = Dictionary(packs.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        return names.compactMap { byName[$0] }
    }
}
