import SwiftUI

/// The one surface every screen lives on: a warm desk mat. Putty-toned felt
/// in light mode, deep charcoal felt in dark — with the same grain shader the
/// cards use, so paper and desk read as one physical scene. Cards sit ON this;
/// panels are paper laid on it.
struct DeskSurface: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let top    = scheme == .dark ? Color(red: 0.105, green: 0.103, blue: 0.098)
                                     : Color(red: 0.937, green: 0.916, blue: 0.882)
        let bottom = scheme == .dark ? Color(red: 0.082, green: 0.080, blue: 0.076)
                                     : Color(red: 0.906, green: 0.882, blue: 0.843)
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .paperGrain(strength: scheme == .dark ? 0.016 : 0.026)
            .ignoresSafeArea()
    }
}

extension View {
    /// Places this screen on the shared desk mat.
    func deskSurface() -> some View {
        background(DeskSurface())
    }
}
