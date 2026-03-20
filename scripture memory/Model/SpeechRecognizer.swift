import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var permissionDenied = false

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

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.requestMicAndBegin()
                default:
                    self.permissionDenied = true
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
                }
            }
        }
    }

    private func beginRecognition() {
        guard let recognizer, recognizer.isAvailable else { return }

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
                    self.stopListening()
                }
            }
        }

        do {
            try audioEngine.start()
            transcript = ""
            isListening = true
        } catch {
            stopListening()
        }
    }
}
