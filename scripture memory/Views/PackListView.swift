import SwiftUI

struct PackListView: View {
    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
    @State private var selectedPack: Pack? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(bibleVersion.packs) { pack in
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

    private var isDEP:        Bool  { pack.name.hasPrefix("DEP") }
    private var baseColor:    Color { (Color(hex: pack.color) ?? .gray).muted }
    private var displayTitle: String {
        isDEP ? pack.name
                    .replacingOccurrences(of: "DEP ", with: "")
                    .replacingOccurrences(of: ": ",  with: ". ")
              : pack.name
    }

    var body: some View {
        Group {
            if isDEP              { depCover   }
            else if pack.name == "TMS 60" { tmsCover   }
            else                  { genericCover }
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
                .padding(.leading, 18).padding(.top, 16)
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
                    .padding(.trailing, 18).padding(.bottom, 28)
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
                .padding(.horizontal, 18).padding(.bottom, 12)
            }
        }
        .packCoverStyle(border: .white.opacity(0.08))
    }

    // MARK: TMS 60 Style

    private var tmsCover: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(uiColor: UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(white: 0.15, alpha: 1)
                        : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
                })

                VStack(alignment: .leading, spacing: 4) {
                    Text("주제별 성경암송")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .tracking(1)
                        .padding(.leading, 40)

                    HStack(spacing: 4) {
                        Spacer()
                        Text("60")
                            .font(.system(size: 140, weight: .black, design: .monospaced))
                            .foregroundColor(baseColor)
                        VStack(alignment: .center, spacing: 2) {
                            Text("개역한글판")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(baseColor))
                            Text("구절")
                                .font(.system(size: 80, weight: .bold, design: .monospaced))
                                .foregroundColor(baseColor)
                        }
                        Spacer()
                    }
                }
                .padding(.top, 16)
            }

            HStack {
                Text("TO KNOW CHRIST AND TO MAKE HIM KNOWN")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                Spacer()
                HStack(spacing: 5) {
                    Text("네비게이토").tracking(0.5)
                    Image(systemName: "moon.fill")
                    Text("출판사").tracking(0.5)
                }
                .bold()
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.green.opacity(0.15))
        }
        .packCoverStyle(border: Color(.separator).opacity(0.3), shadowOpacity: 0.08)
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
        .packCoverStyle(border: .clear)
    }
}

// MARK: - Pack Cover Style

private extension View {
    func packCoverStyle(border: Color, shadowOpacity: Double = 0.12) -> some View {
        self
            .aspectRatio(5.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 0.5))
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack { PackListView() }
}
