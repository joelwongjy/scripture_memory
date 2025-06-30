/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A representation of a single landmark.
*/

import Foundation
import SwiftUI
import CoreLocation

struct Verse: Hashable, Codable, Identifiable {
    var id: Int
    var title: String
    var verse: String
    var book: String
    var reference: String
    var pack: String
    var subpack: String
}
