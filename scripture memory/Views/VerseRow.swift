/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A single row to be displayed in a list of landmarks.
*/

import SwiftUI

struct VerseRow: View {
    var verse: Verse

    var body: some View {
        HStack {
            Text(verse.book + " " + verse.reference)

            Spacer()
        }
    }
}

#Preview {
    Group {
        VerseRow(verse: verses[0])
        VerseRow(verse: verses[1])
    }
}
