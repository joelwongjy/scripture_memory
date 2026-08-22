import SwiftUI

/// Renders `content` one frame after this view first appears.
///
/// For a screen whose root is a `ScrollView` under a large navigation title
/// and an always-shown search drawer: on a cold launch the scroll view can be
/// laid out *before* the navigation bar has installed the title and the
/// drawer, and it then opens with the title already collapsed (seen on device
/// on iOS 26/27, never in the simulator). Holding the scroll view back for one
/// frame lets the bar settle first, so the scroll view's first layout — the one
/// that decides the title state — happens against the finished chrome.
///
/// Keep the navigation and search modifiers on *this* view, not the content,
/// so the bar is configured in the first frame and only the scrolling part waits.
struct MountAfterFirstFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var isMounted = false

    var body: some View {
        ZStack {
            if isMounted { content() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !isMounted else { return }
            DispatchQueue.main.async { isMounted = true }
        }
    }
}
