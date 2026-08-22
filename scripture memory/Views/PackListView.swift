import SwiftUI

struct PackListView: View {
    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @State private var selectedPack:   Pack?             = nil
    @State private var searchText:     String            = ""
    @State private var searchSelected: VerseSearchResult? = nil
    @State private var showOrganizer:  Bool              = false

    /// Visible packs in the user's custom order (hidden removed).
    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    /// Name of the pack holding the current stopped verse — badged in the grid so
    /// the user can spot where to resume at a glance.
    private var currentPackName: String? { learning.currentVerse?.packName }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // MARK: - Body

    var body: some View {
        // One scroll view for the whole screen, with the grid and the search
        // results swapping *inside* it. Two alternating scroll views left
        // `.searchable` bound to whichever mounted first, so the screen opened
        // already scrolled past its own large title.
        ScrollView {
            if searchText.isEmpty {
                packGrid
            } else {
                VerseSearchResultsList(
                    query:   searchText,
                    results: VerseSearch.results(for: searchText, in: visiblePacks),
                    onSelect: { searchSelected = $0 }
                )
            }
        }
        // Start at the top, explicitly.
        //
        // A `.navigationBarDrawer(displayMode: .always)` search field is laid out
        // as part of the scroll content, and SwiftUI's initial content offset
        // sometimes lands *below* it — the screen opens with the search bar under
        // the status bar and the large title already scrolled away. Naming the
        // anchor removes the guess; it's inert when the offset was right anyway.
        .defaultScrollAnchor(.top)
        .scrollDismissesKeyboard(.immediately)
        .animation(nil, value: searchText.isEmpty)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Packs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showOrganizer = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Organize packs")
            }
        }
        .sheet(isPresented: $showOrganizer) {
            PackOrganizerView(allPacks: bibleVersion.packs)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search verses"
        )
        // See `SRSDashboardView` — index built off the interaction path.
        .task { VerseSearch.prewarm(visiblePacks) }
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

    /// The pack grid, with the favourites collection leading it when the user has
    /// starred anything. It's presented as a pack rather than a separate screen so
    /// everything a pack can do — read, review, shuffle — works on it unchanged.
    private var packGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if let favorites = favorites.pack(in: visiblePacks) {
                packTile(favorites)
            }
            ForEach(visiblePacks) { pack in
                packTile(pack)
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 12)
        // See `SRSDashboardView.dashboard` — same cold-launch offset race.
        .pinsInitialScrollOffsetToTop()
    }

    private func packTile(_ pack: Pack) -> some View {
        Button {
            guard !pack.verses.isEmpty else { return }
            selectedPack = pack
        } label: {
            PackCover(pack: pack, isCurrentPack: pack.name == currentPackName)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name), \(pack.verses.count) cards")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Pack Cover

/// Renders at a fixed 340pt design canvas and scales uniformly to any actual width.
/// Font sizes and layout are written once — no compact/full variants needed.
struct PackCover: View {
    let pack: Pack
    var isCurrentPack: Bool = false

    private static let designWidth:  CGFloat = 340
    private static let designHeight: CGFloat = designWidth * 3 / 5  // 5:3

    /// The one horizontal inset every element on a cover measures from, left and
    /// right alike.
    ///
    /// The printed pack doesn't work this way — its 242 runs nearly to the card
    /// edge while the title and Navigators mark sit well inside, which is fine on
    /// a physical card you hold one at a time. Reproduced in a two-column grid it
    /// just reads as bad centring, so fidelity loses to symmetry here.
    private static let contentInset: CGFloat = 28

    private var isDEP:        Bool  { pack.name.hasPrefix("DEP") }
    private var isTMS180:     Bool  { pack.name.hasPrefix("TMS 180") }
    private var isFavorites:  Bool  { pack.name == FavoritesStore.packName }

    /// The printed field colour, used as authored.
    ///
    /// Not `.muted`. That knocked 45% off the saturation and 30% off the
    /// brightness of every cover — a reasonable hedge when the colours came from
    /// a website where anyone could pick neon green, but these are read off the
    /// physical packs and are already flat print inks. Muting them just made
    /// every pack look like a washed-out version of itself.
    private var fieldColor: Color { Color(hex: pack.color) ?? .gray }

    /// Perceived lightness of the field, so type can pick its own colour.
    ///
    /// DEP 1 is printed on white stock with red type while the rest are white on
    /// solid colour — driving that off luminance rather than the pack's name
    /// means a colour changed later in Supabase stays legible on its own.
    /// Only near-white stock counts. The threshold has to sit high: the yellow
    /// pack is 0.74 and the orange 0.66 on this scale, yet both are printed white
    /// on colour like the rest of the set — it's pack 1's white card, at 0.94,
    /// that's the exception. A more intuitive-looking 0.65 flipped three packs to
    /// red type and a ghosted watermark.
    private var fieldIsLight: Bool {
        let ui = UIColor(fieldColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.85
    }

    /// Type colour for a coloured field: white, or the Navigators red on the
    /// white-stock pack.
    private var inkColor: Color {
        fieldIsLight ? Color(red: 0.72, green: 0.16, blue: 0.11) : .white
    }
    private var baseColor:    Color { (Color(hex: pack.color) ?? .gray).muted }
    private var displayTitle: String {
        isDEP ? pack.name
                    .replacingOccurrences(of: "DEP ", with: "")
                    .replacingOccurrences(of: ": ",  with: ". ")
              : pack.name
    }

    private var borderColor: Color {
        // The white-stock DEP pack needs a real edge or it dissolves into the
        // grouped background behind it.
        if isDEP { return fieldIsLight ? Color(.separator).opacity(0.5) : .white.opacity(0.08) }
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
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous).stroke(borderColor, lineWidth: 0.5))
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
            .overlay(alignment: .topTrailing) {
                if isCurrentPack { currentPackBadge.padding(8) }
            }
    }

    /// "Current" chip marking the pack that holds the learning cursor. White
    /// capsule so it reads on any cover colour.
    private var currentPackBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bookmark.fill").font(.system(size: 9, weight: .bold))
            Text("Current").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
        .accessibilityLabel("Current pack")
    }

    @ViewBuilder
    private var cardContent: some View {
        if isFavorites                       { favoritesCover    }
        else if isDEP                        { depCover          }
        else if isTMS180                     { tms180Cover       }
        else if pack.name == "TMS 60"        { tmsCover          }
        else if pack.name == "5 Assurances"  { assurancesCover   }
        else                                 { genericCover      }
    }

    // MARK: 5 Assurances Style
    //
    // After the cover of *Lessons on Assurance*, the book these five verses are
    // drawn from: olive field, a leaf-and-tendril line drawing, the title set in
    // serif with the second word carrying the weight, and the "Growing in Christ
    // Series" block in a darker band along the bottom.

    private var assurancesCover: some View {
        let band = fieldColor.darkened(by: 0.34)
        return ZStack {
            fieldColor

            LeafBranch()
                .stroke(Color.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 168, height: 132)
                .offset(x: 78, y: -4)

            // One line at the same weight as every other cover's title.
            //
            // This started as the book's own treatment — a small "Lessons on"
            // over a large "ASSURANCE" — which looked right in isolation and
            // wrong in the grid: a 37pt word beside DEP's 23pt titles made this
            // pack shout, and the tiny "5" above it read as a stray number
            // rather than part of the name. The serif, the leaf and the series
            // band carry the book's character; the title doesn't have to.
            VStack(alignment: .leading, spacing: 0) {
                Text("5 Assurances")
                    .font(.system(size: 24, design: .serif))
                    .foregroundColor(.white)
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 26).padding(.top, 18).padding(.trailing, 110)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text("\(pack.verses.count) cards")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: -1) {
                        Text("Growing in")
                            .font(.system(size: 9, design: .serif))
                            .foregroundColor(.white.opacity(0.75))
                        Text("CHRIST")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(.white)
                            .tracking(1.5)
                        Text("Series")
                            .font(.system(size: 9, design: .serif))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(band)
            }
        }
    }

    // MARK: Favourites Style

    /// Deliberately unlike the published covers around it: this one is the user's
    /// own collection, not a booklet, and it shouldn't read as another product.
    private var favoritesCover: some View {
        ZStack {
            baseColor

            Image(systemName: "star.fill")
                .font(.system(size: 150))
                .foregroundColor(.white.opacity(0.1))
                .offset(x: 95, y: 10)

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                    Text(pack.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(pack.verses.count) starred")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
            }
            .padding(18)
        }
    }

    // MARK: DEP 242 Style
    //
    // Faithful to the printed pack: numbered title top-left in plain sans, the
    // gold DEP wordmark with an outlined 242 tucked under it bottom-right, and
    // the Navigators mark bottom-left. Pack 1 is white stock with red type; the
    // rest are white on a solid field.

    /// Ink for the DEP/242 lockup.
    ///
    /// Two inks, split by hue, plus a watermark on the white-stock pack.
    ///
    /// The warm half (red, orange, yellow, green) all carry the *same* pale
    /// cream-gold — pack 5's green field has a yellow wordmark, not a green one,
    /// so this is a second ink rather than a tint of the field. It is much paler
    /// than a saturated gold: against the yellow pack it's barely a shade lighter
    /// than the field, which is exactly how that one prints.
    ///
    /// The cool half (sky, royal, violet) is *not* white, which is what this
    /// assumed and what read wrong on packs 6–8. Each carries a lightened version
    /// of its own field colour: the violet pack's wordmark is periwinkle, the
    /// royal pack's a pale steel blue, the sky pack's a near-white ice blue.
    /// Deriving it from the field reproduces all three from one rule.
    ///
    /// Decided by hue rather than by pack name, so a colour edited later in
    /// Supabase picks the right ink on its own.
    private var depGold: Color {
        if fieldIsLight { return Color(red: 0.91, green: 0.83, blue: 0.78) }

        let ui = UIColor(fieldColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let degrees = h * 360
        let isCool = degrees >= 185 && degrees <= 300      // sky through violet
        // 0.62 toward white, not 1.0: enough separation from the field to read at
        // a glance while keeping the hue that's plainly there on the printed card.
        return isCool ? fieldColor.lightened(by: 0.62)
                      : Color(red: 0.94, green: 0.86, blue: 0.55)
    }

    private var depCover: some View {
        ZStack {
            fieldColor

            VStack {
                HStack {
                    // 27 medium is the ceiling, not a preference. The cover renders
                    // on a fixed 340pt canvas and scales uniformly, so whether a
                    // title wraps is a property of this number alone — identical on
                    // an SE and a Pro Max. The two longest titles in the set
                    // ("7. The Lordship of Christ" and "1. Assurance of Salvation")
                    // measure 275pt at this size against the 284 an equal inset
                    // leaves; 26 needs 286 and drops them to two lines, so this is
                    // as large as the set goes with symmetric margins.
                    Text(displayTitle)
                        .font(.system(size: 25, weight: .medium))
                        .foregroundColor(inkColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                // 12, not 16. A 23pt line box carries ~4pt of ascender space above
                // the cap, so equal padding top and bottom does not read as equal:
                // measured off screenshots, 16/12 gave a ~20pt optical gap at the
                // top against ~13pt at the bottom. These numbers are chosen so the
                // *ink* sits the same distance from both edges.
                .padding(.leading, Self.contentInset)
                .padding(.trailing, Self.contentInset)
                .padding(.top, 18)
                Spacer(minLength: 0)
            }

            // DEP / NIV / 242 lockup, positioned from measurements off the
            // printed pack rather than stacked and hoped for.
            //
            // The three are not a neat right-aligned column: 242 is the largest
            // and runs almost to the card edge, DEP is smaller and sits well
            // inside it, and NIV is tucked into the gap between them at the
            // right. Stacking DEP over 242 in a VStack — which is what this was —
            // lines up two edges that don't line up in print, and shrinks the 242
            // to look like a caption under a heading instead of the other way
            // round.
            ZStack(alignment: .bottomTrailing) {
                OutlinedText(text: "242",
                             font: .system(size: 64, weight: .black).italic(),
                             stroke: depGold,
                             fill: fieldColor,
                             width: 1.5)
                    .padding(.trailing, Self.contentInset)
                    .padding(.bottom, 6)

                // 62, not 55. The two are sized very differently, so equal-looking
                // paddings don't give equal-looking gaps: at 46pt DEP's baseline
                // lands ~66pt off the bottom edge while the 64pt numeral's cap top
                // lands ~67pt — within a point of each other, so the glyphs touch
                // wherever they overlap horizontally. This lifts DEP clear.
                Text("DEP")
                    .font(.system(size: 42, weight: .black))
                    .italic()
                    .tracking(-0.5)
                    .foregroundColor(depGold)
                    .padding(.trailing, Self.contentInset + 59)
                    .padding(.bottom, 62)

                // Clear above the 242, not tucked into it.
                //
                // On the printed pack this sits right in the notch above the
                // numeral, and copying that measurement literally reads as a
                // collision on screen: the italic slant throws the last "2"'s
                // top-right corner out underneath it, and the outlined numeral is
                // drawn with a stroke that widens its bounds further. Given the
                // choice between matching a tight print detail and looking
                // deliberate, this takes the clearance.
                // Serif, unlike everything else in the lockup. DEP, 242 and the
                // Navigators wordmark are all sans on the printed pack — a heavy
                // geometric italic and a condensed grotesque — but the translation
                // mark is set in a roman italic with visible serifs.
                Text("NIV")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(depGold)
                    .padding(.trailing, Self.contentInset + 3)
                    .padding(.bottom, 72)
            }
            // Fill the card. Without this the ZStack shrinks to fit the lockup and
            // the enclosing ZStack centres that block in the middle of the cover —
            // the `bottomTrailing` alignment then only positions the three pieces
            // relative to each other, not against the card. The paddings above are
            // all measured from the card's own edges, so they only mean anything
            // once this stack actually spans it.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            VStack {
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 11))
                            Text("THE NAVIGATORS")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.2)
                        }
                        // The printed card carries the price here. A price means
                        // nothing in the app, so the slot keeps its shape and
                        // says something worth knowing instead.
                        Text("\(pack.verses.count) cards")
                            .font(.system(size: 10))
                            .opacity(0.8)
                    }
                    .foregroundColor(inkColor)
                    Spacer(minLength: 0)
                }
                // 15 against the title's 12 — the 10pt line here has almost no
                // descender slack, so it needs the larger number to land at the
                // same optical distance from the edge.
                .padding(.leading, Self.contentInset).padding(.bottom, 15)
            }
        }
    }

    // MARK: TMS 180 Style
    //
    // "series N" small at top-right, the title right-aligned and bold beneath it,
    // and the Korean publisher line bottom-left.

    private var tms180Cover: some View {
        ZStack {
            fieldColor

            VStack(alignment: .trailing, spacing: 4) {
                Text(seriesLabel)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.95))
                Text(seriesTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20).padding(.top, 16).padding(.leading, 20)

            VStack {
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("네비게이토")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "moon.fill")
                                .font(.system(size: 10))
                            Text("출판사")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("TO KNOW CHRIST AND TO MAKE HIM KNOWN")
                            .font(.system(size: 7, weight: .medium))
                            .tracking(0.2)
                    }
                    .foregroundColor(.white.opacity(0.92))
                    Spacer(minLength: 0)
                    Text("\(pack.verses.count) cards")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
    }

    /// `TMS 180 · Growing in Faith` -> `series 3`, from the pack's own position
    /// in the series rather than anything in its name.
    private var seriesLabel: String {
        let code = VerseNumbering.packCode(for: pack.name)   // "TMS 180 S3"
        let number = code.split(separator: "S").last.map(String.init) ?? ""
        return number.isEmpty ? "" : "series \(number)"
    }

    /// The part after the separator — the title as printed on the pack.
    private var seriesTitle: String {
        pack.name.components(separatedBy: " · ").last ?? pack.name
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
                                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(baseColor))
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

#Preview {
    NavigationStack { PackListView() }
}
