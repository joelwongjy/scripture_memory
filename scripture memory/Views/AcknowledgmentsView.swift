import SwiftUI

/// Dedicated screen for the scripture + content attributions, linked from
/// Settings → About. Keeps the required NIV copyright notice and the Topical
/// Memory System credit out of the main Settings footer (and makes them easy to
/// find).
struct AcknowledgmentsView: View {
    var body: some View {
        List {
            Section("Scripture") {
                Text("Scripture quotations taken from The Holy Bible, New International Version® NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.")
            }
            Section("Topical Memory System") {
                Text("Verse selections are based on The Navigators' Topical Memory System®. This app is independent and is not affiliated with, endorsed by, or sponsored by The Navigators.")
            }
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Acknowledgments") {
    NavigationStack { AcknowledgmentsView() }
}
