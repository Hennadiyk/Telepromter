//
//  VoiceScrollViewModel.swift
//  Teleprompter DE
//

import AVFoundation
import Speech
import Observation

@Observable @MainActor
final class VoiceScrollViewModel {

    // MARK: - Observable state

    private(set) var isActive = false
    private(set) var matchedWordIndex: Int = 0
    private(set) var wordsPerSecond: Double = 2.5

    // MARK: - Private state

    @ObservationIgnored private var scriptTokens: [String] = []
    @ObservationIgnored private var currentWordIndex = 0
    @ObservationIgnored private var processedSpokenCount = 0
    @ObservationIgnored private var lastBatchTime: CFTimeInterval = 0

    // Visible-window alignment: scan [currentWordIndex, searchWindowEnd] until first match.
    @ObservationIgnored private var isAligned = false
    @ObservationIgnored private var searchWindowEnd = 0

    // Incremented on every start() AND every restartSession(). Completion handlers
    // capture this value at task-creation time; if it no longer matches when the
    // handler fires, the handler exits silently. This is the sole cascade-prevention
    // mechanism — no pendingRestartWork DispatchWorkItem is needed.
    @ObservationIgnored private var sessionGeneration = 0

    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var audioEngine: AVAudioEngine?

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
    }

    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Lifecycle

    func start(words: [String], firstVisible: Int = 0, lastVisible: Int = Int.max) {
        tearDownSession()

        scriptTokens = tokenize(words: words)
        guard !scriptTokens.isEmpty else { return }

        let clampedFirst = max(0, min(firstVisible, scriptTokens.count - 1))
        let clampedLast  = max(clampedFirst, min(lastVisible, scriptTokens.count - 1))

        currentWordIndex     = clampedFirst
        searchWindowEnd      = clampedLast
        isAligned            = false
        processedSpokenCount = 0
        lastBatchTime        = 0
        wordsPerSecond       = 2.5
        matchedWordIndex     = currentWordIndex

        sessionGeneration   += 1          // invalidate all callbacks from prior session
        isActive             = true
        beginRecognitionSession()
    }

    func stop() {
        isActive = false
        tearDownSession()
    }

    // MARK: - Session teardown

    private func tearDownSession() {
        recognitionTask?.cancel(); recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Recognition session (cold start — always called from start() or cold restart)

    private func beginRecognitionSession() {
        let gen = sessionGeneration

        let locale = Locale.current
        recognizer = SFSpeechRecognizer(locale: locale)
                  ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.defaultTaskHint = .dictation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Use on-device only when the model is confirmed downloaded — avoids the
        // aggressive silence timeouts that on-device triggers when unavailable.
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        if #available(iOS 16, *) { request.addsPunctuation = false }
        recognitionRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isActive = false
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
            return
        }
        audioEngine = engine

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.isActive, self.sessionGeneration == gen else { return }
                if let result { self.handleResult(result) }
                if error != nil || result?.isFinal == true {
                    self.restartSession()
                }
            }
        }
    }

    // MARK: - Error/silence restart

    private func restartSession() {
        // Increment generation FIRST — any completion handlers that fire after this
        // (e.g. the cancel-triggered error from the task we're about to cancel) will
        // capture stale gen values and silently exit, preventing cascade restarts.
        sessionGeneration += 1
        let gen = sessionGeneration

        recognitionRequest = nil        // stop audio feeding immediately
        recognitionTask?.cancel()       // its completion fires with stale gen → no cascade
        recognitionTask = nil
        processedSpokenCount = 0

        // Only rewind currentWordIndex the first time after aligned speech.
        // Without this guard, cascade isFinal fires during silence would walk
        // currentWordIndex all the way back to 0, pushing the search window
        // far behind the user's actual position.
        if isAligned {
            let rewindBy = min(3, currentWordIndex)
            currentWordIndex -= rewindBy
            isAligned = false
        }
        searchWindowEnd = min(currentWordIndex + 20, scriptTokens.count - 1)

        guard isActive else { return }

        if let engine = audioEngine, engine.isRunning {
            // Hot restart: reuse running engine, swap request and task immediately.
            // No delay — a gap here would swallow the first syllable after a pause,
            // preventing re-alignment when the user resumes speaking.
            let locale = Locale.current
            recognizer = SFSpeechRecognizer(locale: locale)
                      ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            recognizer?.defaultTaskHint = .dictation

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer?.supportsOnDeviceRecognition == true {
                request.requiresOnDeviceRecognition = true
            }
            if #available(iOS 16, *) { request.addsPunctuation = false }
            recognitionRequest = request    // audio flows to new request immediately

            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.isActive, self.sessionGeneration == gen else { return }
                    if let result { self.handleResult(result) }
                    if error != nil || result?.isFinal == true {
                        self.restartSession()
                    }
                }
            }
        } else {
            // Cold restart: engine stopped due to system audio interruption.
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
            beginRecognitionSession()
        }
    }

    // MARK: - Word matching

    private func handleResult(_ result: SFSpeechRecognitionResult) {
        let words = result.bestTranscription.formattedString
            .components(separatedBy: .whitespaces)
            .map { normalizeWord($0) }
            .filter { !$0.isEmpty }

        guard words.count > processedSpokenCount else { return }
        let newWords = Array(words[processedSpokenCount...])
        processedSpokenCount = words.count

        let prevIndex = currentWordIndex
        for word in newWords { tryAdvance(spokenWord: word) }
        let matched = currentWordIndex - prevIndex
        guard matched > 0 else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if lastBatchTime > 0 {
            let elapsed = max(0.1, now - lastBatchTime)
            let rate = Double(matched) / elapsed
            wordsPerSecond = wordsPerSecond * 0.82 + max(0.5, min(rate, 4.0)) * 0.18
        }
        lastBatchTime = now
        matchedWordIndex = currentWordIndex
    }

    private func tryAdvance(spokenWord: String) {
        guard currentWordIndex < scriptTokens.count else { return }

        if !isAligned {
            // Scan visible window to find where the user actually is on screen
            let windowEnd = min(searchWindowEnd + 1, scriptTokens.count)
            for i in currentWordIndex..<windowEnd {
                if wordsMatch(spokenWord, scriptTokens[i]) {
                    currentWordIndex = i + 1
                    isAligned = true
                    return
                }
            }
            return
        }

        for skip in 0...2 {
            let i = currentWordIndex + skip
            guard i < scriptTokens.count else { break }
            if wordsMatch(spokenWord, scriptTokens[i]) {
                currentWordIndex = i + 1
                return
            }
        }
    }

    private func wordsMatch(_ spoken: String, _ expected: String) -> Bool {
        guard !spoken.isEmpty, !expected.isEmpty else { return false }
        if spoken == expected { return true }
        if spoken.count >= 4, expected.hasPrefix(spoken) { return true }
        if expected.count >= 4, spoken.hasPrefix(expected) { return true }
        if spoken.count >= 5, expected.count >= 5 { return levenshtein(spoken, expected) <= 1 }
        return false
    }

    // MARK: - Text normalization

    private func tokenize(words: [String]) -> [String] {
        words.flatMap { $0.components(separatedBy: "-") }
             .map { normalizeWord($0) }
             .filter { !$0.isEmpty }
    }

    private func normalizeWord(_ word: String) -> String {
        word.lowercased().filter { $0.isLetter }
    }

    // MARK: - Levenshtein distance

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var dp = Array(0...n)
        for i in 1...m {
            var prev = dp[0]; dp[0] = i
            for j in 1...n {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, min(dp[j], dp[j-1])) + 1
                prev = temp
            }
        }
        return dp[n]
    }
}
