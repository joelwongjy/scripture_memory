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
    @State private var inputTitle: String = ""
    @State private var inputVerse: String = ""
    @State private var feedbackTitle: [WordFeedback] = []
    @State private var feedbackVerse: [WordFeedback] = []
    @State private var showAnswers: Bool = false
    
    private var verseTitle: [String] {
        verse.title.components(separatedBy: " ")
    }
    
    private var verseWords: [String] {
        verse.verse.components(separatedBy: " ")
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Single Verse Card
                VStack(alignment: .leading, spacing: 20) {
                    // Header with reveal button
                    HStack {
                        Text(verse.book + " " + verse.reference)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(showAnswers ? "Hide Answer" : "Reveal Answer") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAnswers.toggle()
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                    
                    Divider()
                    
                    // Title Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if showAnswers {
                            Text(verse.title)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            feedbackTitle.enumerated().reduce(Text("")) { result, pair in
                                let (_, word) = pair
                                return result + Text(word.word + " ")
                                    .foregroundColor(color(for: word.isCorrect))
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        
                        if !showAnswers {
                            TextField("Type the title here...", text: $inputTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 44)
                                .onChange(of: inputTitle) { newValue in
                                    // Debounce the processing to prevent hangs
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        feedbackTitle = processInput(feedbackWords: feedbackTitle, answerWords: verseTitle, text: newValue)
                                    }
                                }
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.default)
                                .disabled(inputTitle.count >= verseTitle.joined(separator: " ").count)
                        }
                    }
                    
                    Divider()
                    
                    // Verse Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Verse")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if showAnswers {
                            Text(verse.verse)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            feedbackVerse.enumerated().reduce(Text("")) { result, pair in
                                let (_, word) = pair
                                return result + Text(word.word + " ")
                                    .foregroundColor(color(for: word.isCorrect))
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        
                        if !showAnswers {
                            TextField("Type the verse here...", text: $inputVerse, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 80)
                                .lineLimit(3...8)
                                .onChange(of: inputVerse) { newValue in
                                    // Debounce the processing to prevent hangs
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        feedbackVerse = processInput(feedbackWords: feedbackVerse, answerWords: verseWords, text: newValue)
                                    }
                                }
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.default)
                                .disabled(inputVerse.count >= verseWords.joined(separator: " ").count)
                        }
                    }
                    
                    // Reset Button
                    if !showAnswers && (!inputTitle.isEmpty || !inputVerse.isEmpty) {
                        HStack {
                            Spacer()
                            Button("Reset Progress") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    inputTitle = ""
                                    inputVerse = ""
                                    feedbackTitle = []
                                    feedbackVerse = []
                                }
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                            Spacer()
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }
    
    // MARK: - Logic
    
    private func processInput(feedbackWords: [WordFeedback], answerWords: [String], text: String) -> [WordFeedback] {
        // Early return for empty inputs
        guard !text.isEmpty, !answerWords.isEmpty else { return [] }
        
        // Limit processing to prevent hangs
        let maxLength = min(text.count, answerWords.count, 100) // Cap at 100 characters
        let processText = String(text.prefix(maxLength))
        
        var result: [WordFeedback] = []
        
        // Process character by character with bounds checking
        for (index, char) in processText.enumerated() {
            guard index < answerWords.count else { break }
            
            let targetWord = answerWords[index]
            guard let targetChar = targetWord.first else { continue }
            
            let isCorrect = char.lowercased() == targetChar.lowercased()
            result.append(WordFeedback(word: targetWord, isCorrect: isCorrect))
            
            // Trigger haptic only on word completion (space or end)
            if char == " " || index == processText.count - 1 {
                triggerHaptic(success: isCorrect)
            }
        }
        
        return result
    }
    
    private func triggerHaptic(success: Bool) {
        // Throttle haptic feedback to prevent excessive calls
        struct HapticThrottle {
            static var lastHapticTime: Date = .distantPast
        }
        
        let now = Date()
        guard now.timeIntervalSince(HapticThrottle.lastHapticTime) > 0.1 else { return }
        HapticThrottle.lastHapticTime = now
        
        Task { @MainActor in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(success ? .success : .error)
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
