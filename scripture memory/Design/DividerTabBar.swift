import SwiftUI

// MARK: - App tabs

/// Top-level sections, styled as the labeled divider tabs in a card box.
enum AppTab: String, CaseIterable, Identifiable {
    case home, packs, quiz, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .packs:    return "Packs"
        case .quiz:     return "Quiz"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .packs:    return "rectangle.stack.fill"
        case .quiz:     return "checkmark.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Divider tab shape

/// An index-card divider tab: slightly tapered sides, rounded top corners,
/// open bottom — the tab you'd grab to pull a section of cards forward.
struct DividerTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset  = min(rect.width * 0.07, 7)
        let radius = min(9, rect.height / 3)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + radius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset + radius, y: rect.minY),
                       control: CGPoint(x: rect.minX + inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - inset, y: rect.minY + radius),
                       control: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Divider tab bar

/// The app's navigation: four divider tabs standing in a card box. The
/// selected tab is pulled up and forward (taller, parchment-filled); the
/// others sit back in the box. Springy, with a soft haptic per pull.
struct DividerTabBar: View {
    @Binding var selection: AppTab

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                dividerTab(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        .background {
            // The lip of the card box the dividers stand in.
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func dividerTab(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        return Button {
            guard selection != tab else { return }
            HapticEngine.soft()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            // The pulled tab is taller — it rises out of the box.
            .padding(.bottom, isSelected ? 12 : 6)
            .background {
                DividerTabShape()
                    .fill(isSelected ? tabFill : Color.clear)
                    .overlay {
                        DividerTabShape()
                            .stroke(isSelected ? Color(.separator).opacity(0.6) : .clear, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 3, x: 0, y: -1)
            }
            .contentShape(DividerTabShape())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Parchment tone for the pulled tab — same family as the cards.
    private var tabFill: Color {
        scheme == .dark ? Color(white: 0.16) : Color(red: 0.985, green: 0.972, blue: 0.945)
    }
}
