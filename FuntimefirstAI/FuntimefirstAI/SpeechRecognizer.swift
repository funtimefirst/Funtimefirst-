import Foundation
import Speech
import AVFoundation

class SpeechRecognizer {
    @Published var transcript: String = ""

    var onAutoStopped: (() -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startRecording(completion: @escaping (Error?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                completion(NSError(domain: "SpeechRecognizer", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized. Please enable it in Settings."]))
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else {
                    completion(NSError(domain: "SpeechRecognizer", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Microphone access denied. Please enable it in Settings."]))
                    return
                }
                DispatchQueue.main.async {
                    self?.beginRecording(completion: completion)
                }
            }
        }
    }

    private func beginRecording(completion: @escaping (Error?) -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request else { return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            transcript = ""

            task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    DispatchQueue.main.async {
                        self.transcript = result.bestTranscription.formattedString
                        self.resetSilenceTimer()
                    }
                }
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async {
                        self.stopRecording()
                        self.onAutoStopped?()
                    }
                }
            }

            completion(nil)
        } catch {
            completion(error)
        }
    }

    func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.stopRecording()
            self?.onAutoStopped?()
        }
    }
}
