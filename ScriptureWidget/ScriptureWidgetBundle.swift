import WidgetKit
import SwiftUI

@main
struct ScriptureWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScriptureVerseWidget()
        ScriptureProgressWidget()
    }
}
