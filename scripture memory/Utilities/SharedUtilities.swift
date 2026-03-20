/*
 See the LICENSE.txt file for this sample's licensing information.
 
 Abstract:
 Shared utilities and preference keys for the app.
 */

import SwiftUI

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - String Extensions

extension String {
    func character(at index: Int) -> Character? {
        guard index >= 0 && index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }
}
