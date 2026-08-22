import Foundation

/// Short, shared pieces of user-facing wording that more than one screen needs
/// to phrase identically.
enum Wording {
    static func verses(_ n: Int) -> String { "\(n) \(n == 1 ? "verse" : "verses")" }
}
