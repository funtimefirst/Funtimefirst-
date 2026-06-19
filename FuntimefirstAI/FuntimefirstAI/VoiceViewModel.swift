import Foundation
import Combine
import AVFoundation

@MainActor
class VoiceViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var response: String = ""
    @Published var isRecording: Bool = false
    @Published var statusMessage: String = "Tap the mic to speak"
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let speechRecognizer = SpeechRecognizer()
    private let claudeService = ClaudeService()
    private let synthesizer = AVSpeechSynthesizer()
    private var transcriptCancellable: AnyCancellable?

    init() {
        transcriptCancellable = speechRecognizer.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcript = text
            }

        speechRecognizer.onAutoStopped = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isRecording else { return }
                self.isRecording = false
                self.sendToClaudeIfNeeded()
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            isRecording = false
            statusMessage = "Processing..."
            speechRecognizer.stopRecording()
            sendToClaudeIfNeeded()
        } else {
            beginRecording()
        }
    }

    private func beginRecording() {
        transcript = ""
        response = ""
        statusMessage = "Listening..."

        speechRecognizer.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.present(error: error.localizedDescription)
                } else {
                    self?.isRecording = true
                }
            }
        }
    }

    private func sendToClaudeIfNeeded() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "Tap the mic to speak"
            return
        }
        statusMessage = "Thinking..."
        Task { await askClaude(text) }
    }

    private func askClaude(_ text: String) async {
        do {
            let reply = try await claudeService.sendMessage(text)
            response = reply
            statusMessage = "Speaking..."
            speak(reply)
        } catch {
            present(error: error.localizedDescription)
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)

        let estimatedDuration = Double(text.count) / 14.0
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
            self.statusMessage = "Tap the mic to speak"
        }
    }

    func clearConversation() {
        transcript = ""
        response = ""
        claudeService.clearHistory()
        statusMessage = "Tap the mic to speak"
    }

    private func present(error message: String) {
        errorMessage = message
        showError = true
        statusMessage = "Tap the mic to speak"
        isRecording = false
    }
}
