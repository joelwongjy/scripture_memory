/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 A view showing the details for a landmark.
 */

import SwiftUI


struct WordFeedback {
    let word: String
    var isCorrect: Bool?
}

struct VerseDetail: View {
    var verse: Verse
    @State private var inputText: String = ""
    @State private var feedbackWords: [WordFeedback] = []
    
    private var words: [String] {
        verse.verse.components(separatedBy: " ")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(verse.title)
                    .font(.title2)
                    .bold()
                
                Text(verse.book + " " + verse.reference)
                    .font(.title3)
                
                Divider()
                
                feedbackWords.enumerated().reduce(Text("")) { result, pair in
                    let (_, word) = pair
                    return result + Text(word.word + " ")
                        .foregroundColor(color(for: word.isCorrect))
                        .font(.system(size: 20, weight: .medium))
                }
                
                .padding()
                .frame(maxWidth: .infinity)
                
                TextField("Start typing...", text: $inputText)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .onChange(of: inputText) {
                        processInput($0)
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disabled(inputText.count == words.count)
                    .padding(.horizontal)
                
            }
            .padding()
        }
        .navigationTitle(verse.book + " " + verse.reference)
        //        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Logic
    
    private func processInput(_ text: String) {
        let index = text.count - 1
        
        if index < words.count {
            if (index < feedbackWords.count) {
                feedbackWords.removeSubrange((index + 1)..<feedbackWords.count)
            } else {
                let wordToCheck = words[index]
                let typedChar = text[text.index(text.startIndex, offsetBy: index)].lowercased()
                let correctChar = wordToCheck[wordToCheck.index(wordToCheck.startIndex, offsetBy: 0)].lowercased()
                let isCorrect = typedChar == correctChar
                
                feedbackWords.append(WordFeedback(word: wordToCheck, isCorrect: isCorrect))
            }
            
        }
    }
    
    private func triggerHaptic(success: Bool) {
        DispatchQueue.main.async {
            if success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    private func color(for isCorrect: Bool?) -> Color {
        switch isCorrect {
        case true: return .primary
        case false: return .red
        default: return .gray
        }
    }
}

#Preview {
    VerseDetail(verse: verses[0])
}
