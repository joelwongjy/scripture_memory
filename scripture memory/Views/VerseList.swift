/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view showing a list of landmarks.
*/

import SwiftUI

struct VerseList: View {
    var body: some View {
        NavigationSplitView {
            List(verses) { verse in
                NavigationLink{
                    VerseDetail(verse: verse)
                } label: {
                    VerseRow(verse: verse)
                }
            }
            .navigationTitle("Verses")
        } detail: {
            Text("Select a Verse")
        }
    }
}

#Preview {
    VerseList()
}
