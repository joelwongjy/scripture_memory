/*
 See the LICENSE.txt file for this sample's licensing information.
 
 Abstract:
 A playlist header component that displays artwork, title, and action buttons.
 */

import SwiftUI

struct PackHeader: View {
    let packName: String
    let verseCount: Int
    let onPlayTapped: () -> Void
    let onShuffleTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Large Pack Cover
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: packName),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 220)
                .overlay(
                    VStack {
                        Image(systemName: "book.pages")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(.white)
                        Text(packName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Title and Description
            VStack(spacing: 8) {
                Text(packName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(verseCount) verses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Play and Shuffle Buttons
            HStack(spacing: 16) {
                // Play Button
                Button {
                    onPlayTapped()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Study")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Shuffle Button
                Button {
                    onShuffleTapped()
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Shuffle")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.top, 20) // Reduced padding since we now have navigation bar
        .padding(.bottom, 30)
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
    PackHeader(
        packName: "Hello", verseCount: 12,
        onPlayTapped: {},
        onShuffleTapped: {}
    )
}
