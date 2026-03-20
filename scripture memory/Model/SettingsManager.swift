import SwiftUI

class SettingsManager: ObservableObject {
    @AppStorage("bibleVersion") var bibleVersion: String = "NIV84"
    @AppStorage("typingMode") var typingMode: String = "firstLetter"  // "firstLetter" or "fullWord"
    @AppStorage("checkMode") var checkMode: String = "immediate"      // "immediate" or "submit"
}
