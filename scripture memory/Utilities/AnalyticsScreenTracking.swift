import SwiftUI

extension View {
    func analyticsScreen(_ screen: AnalyticsScreen) -> some View {
        onAppear { Analytics.log(.screenViewed(screen)) }
    }
}
