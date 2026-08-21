import SwiftUI

// MARK: - Error Presentation

extension View {
    /// Reports a failed dictation start. Without it the mic button simply doesn't
    /// light up and the user is left guessing.
    func speechErrorAlert(_ speech: SpeechRecognizer) -> some View {
        alert(
            "Dictation Unavailable",
            isPresented: Binding(
                get: { speech.errorMessage != nil },
                set: { if !$0 { speech.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(speech.errorMessage ?? "")
        }
    }
}
