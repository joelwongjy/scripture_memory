import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var permissionDenied = false

    /// Why dictation couldn't start, for the UI to show. Every failure path below
    /// used to just return, leaving the mic button un-lit and the user with no idea
    /// whether they'd mis-tapped, been denied, or hit something broken.
    @Published var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }
        errorMessage = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.requestMicAndBegin()
                default:
                    self.permissionDenied = true
                    self.errorMessage = "Speech recognition permission was denied. Enable it in Settings › Privacy › Speech Recognition."
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func requestMicAndBegin() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.beginRecognition()
                } else {
                    self.permissionDenied = true
                    self.errorMessage = "Microphone access was denied. Enable it in Settings › Privacy › Microphone."
                }
            }
        }
    }

    private func beginRecognition() {
        // Commonly false in the Simulator, and on device when the speech assets
        // aren't downloaded or the network is down for a locale that needs it.
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. Check your connection and try again."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = [
            "Lord", "God", "Jesus", "Christ", "Holy Spirit",
            "Scripture", "righteousness", "salvation", "eternal",
            "crucified", "resurrection", "sanctify", "justified",
            "commandments", "covenant", "redemption", "forgiveness",
            "Corinthians", "Galatians", "Ephesians", "Philippians",
            "Colossians", "Thessalonians", "Deuteronomy", "Leviticus",
            "Lamentations", "Habakkuk", "Ecclesiastes", "Proverbs",
            "Isaiah", "Jeremiah", "Hebrews", "Revelation", "Psalm",
            "apostles", "disciples", "Gentiles", "Pharisees",
            "temptation", "transgression", "iniquity", "unrighteousness"
        ]
        self.recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the microphone. Another app may be using it."
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    // An error before a single word came through means dictation
                    // never actually got going. Say so, instead of just switching
                    // the mic back off and leaving the user to wonder. Errors after
                    // some speech was transcribed are ordinary end-of-session
                    // teardown and stay silent.
                    if error != nil, self.transcript.isEmpty {
                        self.errorMessage = "Dictation didn't pick up any audio. Check your microphone and try again."
                    }
                    self.stopListening()
                }
            }
        }

        do {
            try audioEngine.start()
            transcript = ""
            isListening = true
        } catch {
            errorMessage = "Couldn't start the microphone. Another app may be using it."
            stopListening()
        }
    }
}

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
