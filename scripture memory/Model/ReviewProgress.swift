import Foundation

// MARK: - Cross-Pack Session

/// Lightweight Identifiable wrapper so PackListView can present a cross-pack
/// study session via fullScreenCover.
struct CrossPackSession: Identifiable {
    let id    = UUID()
    let title: String
    let verses: [Verse]
}

// MARK: - Review Progress

/// Persists which verse IDs the user has fully completed, across all packs and sessions.
/// Backed by UserDefaults so progress survives app restarts.
final class ReviewProgress: ObservableObject {

    static let shared = ReviewProgress()
    private static let udKey = "reviewProgress_completedIds"

    @Published private(set) var completedIds: Set<Int>

    private init() {
        let stored = UserDefaults.standard.array(forKey: Self.udKey) as? [Int] ?? []
        completedIds = Set(stored)
    }

    // MARK: - Mutation

    func markComplete(_ id: Int) {
        guard !completedIds.contains(id) else { return }
        completedIds.insert(id)
        persist()
    }

    func resetAll() {
        completedIds = []
        UserDefaults.standard.removeObject(forKey: Self.udKey)
    }

    // MARK: - Queries

    func isComplete(_ id: Int) -> Bool { completedIds.contains(id) }

    func completedCount(for verses: [Verse]) -> Int {
        verses.filter { completedIds.contains($0.id) }.count
    }

    func fraction(for verses: [Verse]) -> Double {
        guard !verses.isEmpty else { return 0 }
        return Double(completedCount(for: verses)) / Double(verses.count)
    }

    // MARK: - Private

    private func persist() {
        UserDefaults.standard.set(Array(completedIds), forKey: Self.udKey)
    }
}
