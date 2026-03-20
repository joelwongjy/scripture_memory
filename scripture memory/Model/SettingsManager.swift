import SwiftUI

class SettingsManager: ObservableObject {
    @AppStorage("bibleVersion") var bibleVersion: String = "NIV84"
    @AppStorage("studyMode") var studyMode: String = "firstLetter"  // "firstLetter", "fullWord", or "submit"
}
