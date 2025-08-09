/*
 See the LICENSE.txt file for this sample's licensing information.
 
 Abstract:
 A view showing packs in Apple Music style grid layout.
 */

import SwiftUI

struct PacksView: View {
    // Group verses by pack
    private var packGroups: [String: [Verse]] {
        Dictionary(grouping: verses) { $0.pack }
    }
    
    private var packs: [(String, [Verse])] {
        packGroups.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(packs, id: \.0) { packName, packVerses in
                        NavigationLink(destination: VerseList(packName: packName, verses: packVerses)) {
                            PackCard(
                                packName: packName,
                                verseCount: packVerses.count,
                                firstVerse: packVerses.first
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Scripture Memory")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// Individual Pack Card
struct PackCard: View {
    let packName: String
    let verseCount: Int
    let firstVerse: Verse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Album Cover
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: packName),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack {
                        Image(systemName: "book.pages")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundColor(.white)
                        Text(packName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // Pack Info
            VStack(alignment: .leading, spacing: 2) {
                Text(packName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(verseCount) verses")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func gradientColors(for packName: String) -> [Color] {
        switch packName.lowercased() {
        case "basic":
            return [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]
        case "advanced":
            return [Color.green.opacity(0.8), Color.blue.opacity(0.6)]
        case "favorite":
            return [Color.orange.opacity(0.8), Color.red.opacity(0.6)]
        default:
            return [Color.indigo.opacity(0.8), Color.pink.opacity(0.6)]
        }
    }
}

#Preview {
    PacksView()
}
