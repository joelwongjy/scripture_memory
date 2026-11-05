import SwiftUI
import TipKit

struct ReviewCountsTip: Tip {
    var title: Text { Text("New, Learn and Due") }

    var message: Text? {
        Text("New").bold().foregroundStyle(ReviewColor.new)
            + Text(" – verses you haven’t started.\n")
            + Text("Learn").bold().foregroundStyle(ReviewColor.learn)
            + Text(" – verses you haven’t got right yet. They come back soon.\n")
            + Text("Due").bold().foregroundStyle(ReviewColor.due)
            + Text(" – memorised verses scheduled for today. Get them right and they come back less often.")
    }

    var image: Image? { Image(systemName: "lightbulb") }
}

enum ReviewCountHint {
    static let new = "Verses you haven’t started."
    static let learn = "Verses you haven’t got right yet."
    static let due = "Memorised verses scheduled for today."
}
