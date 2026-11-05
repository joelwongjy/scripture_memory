import Foundation

@MainActor
final class AnkiFileInbox: ObservableObject {
    static let shared = AnkiFileInbox()

    @Published var url: URL?
    var openImports = 0
}
