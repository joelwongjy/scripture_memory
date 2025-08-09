/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view showing a list of verses in Apple Music style with Now Playing functionality.
*/

import SwiftUI

struct VerseList: View {
    let packName: String?
    let verses: [Verse]
    @State private var selectedVerse: Verse? = nil
    @State private var isNowPlayingPresented: Bool = false
    @State private var showMiniPlayer: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showNavigationTitle: Bool = false
    
    
    // Pack-specific initializer
    init(packName: String, verses packVerses: [Verse]) {
        self.packName = packName
        self.verses = packVerses
    }
    
    var body: some View {
        let content = ScrollView {
            VStack(spacing: 0) {
                // Header with Playlist Artwork
                PackHeader(
                    packName: packName ?? "missing name",
                    verseCount: verses.count,
                    onPlayTapped: {
                        selectedVerse = verses.first ?? verses[0]
                        showMiniPlayer = true
                        isNowPlayingPresented = true
                    },
                    onShuffleTapped: {
                        selectedVerse = verses.randomElement() ?? verses[0]
                        showMiniPlayer = true
                        isNowPlayingPresented = true
                    }
                )
                
                // Verse List - Optimized
                LazyVStack(spacing: 0) {
                    ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                        VerseRow(
                            verse: verse,
                            index: index + 1,
                            isLast: index == verses.count - 1,
                            onTap: {
                                selectedVerse = verse
                                showMiniPlayer = true
                                isNowPlayingPresented = true
                            }
                        )
                    }
                }
                
                // Bottom spacing for mini player
                if showMiniPlayer {
                    Color.clear
                        .frame(height: 60)
                }
            }
            .padding(.horizontal, 20)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, 
                                   value: geometry.frame(in: .named("scroll")).minY)
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
            showNavigationTitle = scrollOffset < -280
        }
        .background(Color(.systemBackground))
        .overlay(
            // Mini Player Bar
            VStack {
                Spacer()
                if showMiniPlayer, let verse = selectedVerse {
                    MiniPlayerBar(
                        verse: verse,
                        onTap: {
                            isNowPlayingPresented = true
                        },
                        onClose: {
                            showMiniPlayer = false
                            selectedVerse = nil
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showMiniPlayer)
        )
        .sheet(isPresented: $isNowPlayingPresented) {
            if let verse = selectedVerse {
                NowPlayingSheet(
                    verse: verse,
                    onDismiss: {
                        isNowPlayingPresented = false
                    }
                )
            }
        }
        
        // Return different views based on context
        if packName == nil {
            // Main app view with NavigationView
            NavigationView {
                content.navigationBarHidden(true)
            }
        } else {
            // Pack detail view with navigation title
            content
                .navigationTitle(showNavigationTitle ? packName! : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // More options
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }
}

#Preview {
    VerseList(packName: "hello", verses: verses)
}
