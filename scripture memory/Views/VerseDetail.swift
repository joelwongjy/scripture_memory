/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view showing the details for a landmark.
*/

import SwiftUI


struct VerseDetail: View {
    var verse: Verse
    @State var text = ""

    var body: some View {
        ScrollView {
//            MapView(coordinate: landmark.locationCoordinate)
//                .frame(height: 300)
//
//            CircleImage(image: landmark.image)
//                .offset(y: -130)
//                .padding(.bottom, -130)

            VStack(alignment: .leading) {
                Text(verse.title)
                    .font(.title)
                
                Text(verse.book + " " + verse.reference)
                    .font(.headline)
                
                Divider()
                
                Text(verse.verse)
                    .padding(.top)
                
                TextField("Enter Text", text: $text)
                    .padding()

            }
            .padding()
        }
        .navigationTitle(verse.book + " " + verse.reference)
//        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    VerseDetail(verse: verses[0])
}
