import SwiftUI

struct PackListView: View {
    @AppStorage("bibleVersion") private var bibleVersion = "NIV84"
    @State private var selectedPack: Pack? = nil

    private var activePacks: [Pack] {
        bibleVersion == "NIV11" ? packsNIV11 : packsNIV84
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(activePacks) { pack in
                    Button {
                        guard !pack.verses.isEmpty else { return }
                        selectedPack = pack
                    } label: {
                        PackCover(pack: pack)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scripture Memory")
        .fullScreenCover(item: $selectedPack) { pack in
            CardStudyView(packName: pack.name, verses: pack.verses)
        }
    }
}

// MARK: - Pack Cover

struct PackCover: View {
    let pack: Pack

    private var isDEP: Bool { pack.name.hasPrefix("DEP") }

    private var baseColor: Color {
        (Color(hex: pack.color) ?? .gray).muted
    }

    private var displayTitle: String {
        if isDEP {
            return pack.name
                .replacingOccurrences(of: "DEP ", with: "")
                .replacingOccurrences(of: ": ", with: ". ")
        }
        return pack.name
    }

    var body: some View {
        if isDEP {
            depCover
        } else if pack.name == "TMS 60" {
            tmsCover
        } else {
            genericCover
        }
    }

    // MARK: DEP 242 Style

    private var depCover: some View {
        ZStack {
            baseColor

            VStack {
                HStack {
                    Text(displayTitle)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.leading, 18)
                .padding(.top, 16)
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: -8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("DEP")
                                .font(.system(size: 42, weight: .heavy, design: .serif))
                                .italic()
                                .foregroundColor(.white.opacity(0.8))
                            Text("NIV")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Text("242")
                            .font(.system(size: 50, weight: .heavy, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 28)
                }
            }

            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 12))
                        Text("THE NAVIGATORS")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.5)
                    }
                    Spacer()
                    Text("\(pack.verses.count) cards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .aspectRatio(5.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: TMS 60 Style

    private var tmsCover: some View {
        ZStack {
            Color(uiColor: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.15, alpha: 1)
                    : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
            })

            VStack(spacing: 4) {
                Text("Topical Memory System")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Text("60")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundColor(baseColor)

                Text("TO KNOW CHRIST AND TO MAKE HIM KNOWN")
                    .font(.system(size: 8, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
            }

            VStack {
                Spacer()
                HStack {
                    Text("\(pack.verses.count) cards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(Color.secondary.opacity(0.4))
                            .font(.system(size: 12))
                        Text("THE NAVIGATORS")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .aspectRatio(5.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: Generic Style

    private var genericCover: some View {
        ZStack {
            baseColor

            if !pack.accentText.isEmpty {
                Text(pack.accentText)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(x: 80)
            }

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pack.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(pack.verses.count) cards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                VStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(18)
        }
        .aspectRatio(5.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Color Helpers

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }

    var muted: Color {
        let uic = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.55), brightness: Double(b * 0.7))
    }
}

// MARK: - Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        PackListView()
    }
}

// Keep a top-level alias so existing previews that reference `packs` still compile
var packs: [Pack] { packsNIV84 }
