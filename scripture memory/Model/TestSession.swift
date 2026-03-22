import Foundation

struct TestSession: Identifiable {
    let id    = UUID()
    let verses: [Verse]
}
