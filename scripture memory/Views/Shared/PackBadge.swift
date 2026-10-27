import SwiftUI

struct PackBadge: View {
    let pack: Pack
    var width: CGFloat = 46

    var body: some View {
        PackCover(pack: pack, cornerRadius: width * 0.09, showsShadow: false)
            .frame(width: width, height: width / AppLayout.cardAspect)
            .accessibilityHidden(true)
    }
}

extension Pack {
    var tint: Color { fieldIsLight ? inkColor : fieldColor }
}
