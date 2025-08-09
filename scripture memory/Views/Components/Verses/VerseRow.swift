/*
 See the LICENSE.txt file for this sample's licensing information.
 
 Abstract:
 An optimized row view component for displaying verse information in lists.
 */

import SwiftUI

struct VerseRow: View {
    let verse: Verse
    let index: Int
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Track Number
                    Text("\(index)")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    // Verse Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(verse.book) \(verse.reference)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(verse.title)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Pack Badge
                    Text(verse.subpack)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.secondary)
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                
                // Conditional divider for better performance
                if !isLast {
                    Divider()
                        .padding(.leading, 36) // Aligned with content
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        VerseRow(
            verse: verses[0],
            index: 1,
            isLast: false,
            onTap: {}
        )
        VerseRow(
            verse: verses[1],
            index: 2,
            isLast: true,
            onTap: {}
        )
    }
}
