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
    // handler fires, the handler exits silently — this is the cascade-prevention mechanism.
    @ObservationIgnored private var sessionGeneration = 0

    // Fires if no recognition result arrives for 4 seconds, forcing a recovery restart.
    @ObservationIgnored private var watchdogTask: Task<Void, Never>?

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

        sessionGeneration   += 1
        isActive             = true

        scheduleLanguageModelPrep(words: words)
        beginRecognitionSession()
    }

    func stop() {
        isActive = false
        tearDownSession()
    }

    // MARK: - Session teardown

    private func tearDownSession() {
        watchdogTask?.cancel()
        watchdogTask = nil
        recognitionTask?.cancel(); recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Watchdog

    // Resets the 4-second watchdog timer. Called whenever a recognition result arrives
    // and whenever a new task starts. If 4 seconds pass with no result, we force a
    // full restart as a safety net against any stuck-recognition edge case.
    private func resetWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.isActive, !Task.isCancelled else { return }
            self.restartSession(silently: false)
        }
    }

    // MARK: - Recognition session (cold start)

    private func beginRecognitionSession() {
        let gen = sessionGeneration

        let locale = Locale.current
        recognizer = SFSpeechRecognizer(locale: locale)
                  ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.defaultTaskHint = .dictation

        let request = makeRequest()
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

        startRecognitionTask(request: request, gen: gen)
    }

    // MARK: - Session restart

    /// Restarts the recognition task after an isFinal or error.
    ///
    /// - Parameter silently: When `true`, word position and alignment are preserved.
    ///   Use this for empty-transcript isFinal events caused by silence detection —
    ///   they don't represent real end-of-utterance and rewinding would push the search
    ///   window behind the user's actual position. When `false`, rewind slightly and
    ///   clear alignment so the window re-locks on the next spoken word.
    private func restartSession(silently: Bool) {
        sessionGeneration += 1
        let gen = sessionGeneration

        processedSpokenCount = 0

        if !silently, isAligned {
            // Small rewind on real end-of-utterance restarts so the user can repeat
            // a phrase. Kept at 3 words (down from 6) to minimise scroll backward
            // correction needed when the animation catches up.
            let rewindBy = min(3, currentWordIndex)
            currentWordIndex -= rewindBy
            isAligned = false
        }
        searchWindowEnd = min(currentWordIndex + 60, scriptTokens.count - 1)

        guard isActive else {
            watchdogTask?.cancel()
            watchdogTask = nil
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            return
        }

        if let engine = audioEngine, engine.isRunning {
            let locale = Locale.current
            recognizer = SFSpeechRecognizer(locale: locale)
                      ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            recognizer?.defaultTaskHint = .dictation

            let request = makeRequest()

            // Atomic swap: audio tap keeps flowing into the new request immediately —
            // no gap between old and new session. The old task cancel fires with a
            // stale gen value and exits silently.
            recognitionRequest = request
            recognitionTask?.cancel()
            recognitionTask = nil

            startRecognitionTask(request: request, gen: gen)
        } else {
            // Cold restart: engine was killed by a system audio interruption.
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
            beginRecognitionSession()
        }
    }

    // MARK: - Recognition task factory

    private func startRecognitionTask(request: SFSpeechAudioBufferRecognitionRequest, gen: Int) {
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.isActive, self.sessionGeneration == gen else { return }

                if let result { self.handleResult(result) }

                if result?.isFinal == true {
                    // Distinguish between two kinds of isFinal:
                    //
                    // 1. Empty transcript — Apple's silence/VAD detector ended the
                    //    utterance with nothing recognized. This happens when a new
                    //    task starts with buffered silence from the user's pause.
                    //    Restarting with a FULL restart here creates a cascade:
                    //    each new task also sees silence and immediately fires isFinal,
                    //    potentially forever. A SILENT restart preserves word position
                    //    and alignment so re-alignment is instant once speech resumes.
                    //
                    // 2. Non-empty transcript — the user actually finished an utterance.
                    //    Full restart: small rewind, clear alignment, re-lock on next word.
                    let transcript = result?.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    self.restartSession(silently: transcript.isEmpty)
                } else if error != nil {
                    self.restartSession(silently: false)
                }
            }
        }
        resetWatchdog()
    }

    // MARK: - Request factory

    private func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        if #available(iOS 16, *) { request.addsPunctuation = false }
        if #available(iOS 17, *) {
            request.customizedLanguageModel = ScriptLanguageModelManager.shared.configuration
        }
        if !scriptTokens.isEmpty, currentWordIndex < scriptTokens.count {
            let endIdx = min(currentWordIndex + 10, scriptTokens.count)
            request.contextualStrings = Array(scriptTokens[currentWordIndex..<endIdx])
        }
        return request
    }

    // MARK: - Language model preparation

    private func scheduleLanguageModelPrep(words: [String]) {
        if #available(iOS 17, *) {
            ScriptLanguageModelManager.shared.prepare(words: words, locale: Locale.current)
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

        // Receipt of a real result means recognition is alive — reset the watchdog.
        resetWatchdog()
    }

    private func tryAdvance(spokenWord: String) {
        guard currentWordIndex < scriptTokens.count else { return }

        if !isAligned {
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

        for skip in 0...4 {
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
