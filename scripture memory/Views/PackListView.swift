import SwiftUI

struct PackListView: View {
    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84

    @State private var selectedPack:   Pack?             = nil
    @State private var searchText:     String            = ""
    @State private var searchSelected: VerseSearchResult? = nil

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // MARK: - Search Result Model

    struct VerseSearchResult: Identifiable {
        var id: String { "\(pack.name)-\(verse.id)" }
        let verse:      Verse
        let pack:       Pack
        let verseIndex: Int
    }

    // MARK: - Search Logic

    private var searchResults: [VerseSearchResult] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        var results: [VerseSearchResult] = []
        for pack in bibleVersion.packs {
            for (index, verse) in pack.verses.enumerated() {
                let ref = "\(verse.book) \(verse.reference)".lowercased()
                if ref.contains(query)
                    || verse.title.lowercased().contains(query)
                    || verse.verse.lowercased().contains(query) {
                    results.append(VerseSearchResult(verse: verse, pack: pack, verseIndex: index))
                    if results.count == 25 { return results }
                }
            }
        }
        return results
    }

    // MARK: - Body

    var body: some View {
        Group {
            if searchText.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else {
                searchResultsView
            }
        }
        .animation(nil, value: searchText.isEmpty)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Packs")
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: "Search verses"
        )
        .fullScreenCover(item: $selectedPack) { pack in
            NavigationStack {
                CardStudyView(packName: pack.name, verses: pack.verses)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .fullScreenCover(item: $searchSelected) { result in
            NavigationStack {
                CardStudyView(
                    packName: result.pack.name,
                    verses: result.pack.verses,
                    initialIndex: result.verseIndex
                )
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if searchResults.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No results")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { _, result in
                            VStack(spacing: 0) {
                                Button {
                                    searchSelected = result
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(result.verse.book) \(result.verse.reference)")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text(result.verse.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary.opacity(0.82))
                                            Text(result.verse.verse)
                                                .font(.system(size: 12))
                                                .foregroundColor(.primary.opacity(0.68))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .multilineTextAlignment(.leading)
                                            Text(result.pack.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.primary.opacity(0.52))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Pack Cover

/// Renders at a fixed 340pt design canvas and scales uniformly to any actual width.
/// Font sizes and layout are written once — no compact/full variants needed.
struct PackCover: View {
    let pack: Pack

    private static let designWidth:  CGFloat = 340
    private static let designHeight: CGFloat = designWidth * 3 / 5  // 5:3

    private var isDEP:        Bool  { pack.name.hasPrefix("DEP") }
    private var baseColor:    Color { (Color(hex: pack.color) ?? .gray).muted }
    private var displayTitle: String {
        isDEP ? pack.name
                    .replacingOccurrences(of: "DEP ", with: "")
                    .replacingOccurrences(of: ": ",  with: ". ")
              : pack.name
    }

    private var borderColor: Color {
        if isDEP { return .white.opacity(0.08) }
        if pack.name == "TMS 60" { return Color(.separator).opacity(0.3) }
        return .clear
    }

    private var shadowOpacity: Double { pack.name == "TMS 60" ? 0.08 : 0.12 }

    var body: some View {
        Color.clear
            .aspectRatio(5.0 / 3.0, contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    let scale = geo.size.width / Self.designWidth
                    cardContent
                        .frame(width: Self.designWidth, height: Self.designHeight)
                        .clipped()
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 0.5))
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var cardContent: some View {
        if isDEP                      { depCover     }
        else if pack.name == "TMS 60" { tmsCover     }
        else                          { genericCover }
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
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
    }

    // MARK: TMS 60 Style
    //
    // Same 340×204 canvas. One cream field; title + “60” row are one leading-aligned stack, centered
    // as a whole (horizontal + vertical) so the hero isn’t left-weighted inside a wide column.

    private var tmsCover: some View {
        // Slightly shorter footer band so title + hero can use more of the 204pt-tall canvas.
        let footerReserve = CGFloat(36)
        let panel = Color(red: 0.98, green: 0.97, blue: 0.95)

        return ZStack(alignment: .bottom) {
            panel

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 10) {
                        Spacer()
                        Text("주제별 성경암송")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(.black)
                            .tracking(0.4)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                            .multilineTextAlignment(.leading)

                        HStack(alignment: .center, spacing: 8) {
                            Text("60")
                                .font(.system(size: 108, weight: .black, design: .monospaced))
                                .foregroundColor(baseColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("개역한글판")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(baseColor))
                                Text("구절")
                                    .font(.system(size: 62, weight: .bold, design: .monospaced))
                                    .foregroundColor(baseColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.38)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, footerReserve)

            HStack(alignment: .center, spacing: 5) {
                Text("TO KNOW CHRIST AND TO MAKE HIM KNOWN")
                    .font(.system(size: 8.5, weight: .medium, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    Text("네비게이토").tracking(0.25)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 9))
                    Text("출판사").tracking(0.25)
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(.black.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.15))
        }
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
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
