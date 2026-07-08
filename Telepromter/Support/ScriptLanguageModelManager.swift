//
//  ScriptLanguageModelManager.swift
//  Teleprompter DE
//
//  Manages preparation of a custom SFSpeechLanguageModel built from the
//  teleprompter script. Biases the recognizer toward the exact vocabulary
//  and phrase patterns in the script, reducing mis-recognitions and
//  improving response speed after pauses.
//
//  Requires iOS 17+. Used by VoiceScrollViewModel.
//
//  To disable: remove the `scheduleLanguageModelPrep` call from
//  VoiceScrollViewModel.start(). Everything else degrades gracefully to nil.

import Speech

@available(iOS 17, *)
@MainActor
final class ScriptLanguageModelManager {

    static let shared = ScriptLanguageModelManager()
    private init() {}

    // MARK: - Public state

    /// Ready-to-use configuration for SFSpeechAudioBufferRecognitionRequest.customizedLanguageModel.
    /// Nil until preparation completes (or if preparation failed).
    private(set) var configuration: SFSpeechLanguageModel.Configuration?

    // MARK: - Private state

    private var lastScriptHash: String?
    private var prepTask: Task<Void, Never>?

    // MARK: - Public interface

    /// Starts background preparation of a custom language model for the given words.
    /// If the script hasn't changed since the last call (content hash match), this
    /// is a no-op and the cached configuration remains valid.
    func prepare(words: [String], locale: Locale) {
        let hash = Self.fnv1aHash(words)
        guard hash != lastScriptHash else { return }

        prepTask?.cancel()
        configuration = nil

        prepTask = Task { @MainActor [weak self] in
            let config = await Self.buildModel(words: words, locale: locale, hash: hash)
            guard let self, !Task.isCancelled else { return }
            self.configuration = config
            self.lastScriptHash = hash
        }
    }

    /// Discards any in-flight preparation and cached result.
    /// Call this when the script changes before prepare() is called.
    func reset() {
        prepTask?.cancel()
        prepTask = nil
        configuration = nil
        lastScriptHash = nil
    }

    // MARK: - Model construction (runs on cooperative pool, not main actor)

    /// All file I/O and model compilation happen here — never blocks the main thread.
    nonisolated private static func buildModel(
        words: [String],
        locale: Locale,
        hash: String
    ) async -> SFSpeechLanguageModel.Configuration? {

        guard !words.isEmpty else { return nil }
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        // Each unique script gets its own subdirectory keyed by content hash.
        let dir = caches.appendingPathComponent("ScriptLM/\(hash)", isDirectory: true)
        let assetURL = dir.appendingPathComponent("training.bin")
        let modelURL = dir.appendingPathComponent("model")
        let vocabURL = dir.appendingPathComponent("vocab")

        // weight: 0.85 — strong bias toward script vocabulary (iOS 26+).
        // Earlier iOS uses the standard two-argument init (effectively weight 1.0).
        let config: SFSpeechLanguageModel.Configuration
        if #available(iOS 26, *) {
            config = SFSpeechLanguageModel.Configuration(
                languageModel: modelURL,
                vocabulary: vocabURL,
                weight: 0.85
            )
        } else {
            config = SFSpeechLanguageModel.Configuration(
                languageModel: modelURL,
                vocabulary: vocabURL
            )
        }

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        // Export training data only once per unique script content.
        if !FileManager.default.fileExists(atPath: assetURL.path) {
            let trainingData = buildTrainingData(words: words, locale: locale, hash: hash)
            do {
                try await trainingData.export(to: assetURL)
            } catch {
                return nil
            }
        }

        guard !Task.isCancelled else { return nil }

        // Compile into a model. SFSpeechLanguageModel caches the compiled output at
        // modelURL / vocabURL, so subsequent calls with the same paths are instant.
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                SFSpeechLanguageModel.prepareCustomLanguageModel(
                    for: assetURL,
                    configuration: config
                ) { error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
        } catch {
            return nil
        }

        guard !Task.isCancelled else { return nil }
        return config
    }

    nonisolated private static func buildTrainingData(
        words: [String],
        locale: Locale,
        hash: String
    ) -> SFCustomLanguageModelData {
        let data = SFCustomLanguageModelData(
            locale: locale,
            identifier: "com.telepromter.scriptlm.\(hash)",
            version: "1"
        )

        // Individual words — ensures all script vocabulary is in the model.
        // High weight (10) makes these strongly preferred over phonetically similar
        // but contextually wrong alternatives.
        let unique = Array(Set(words.map { $0.lowercased() }))
        for word in unique {
            data.insert(phraseCount: .init(phrase: word, count: 10))
        }

        // Trigrams — teaches likely 3-word sequences from the script. This is the
        // biggest accuracy win: the model learns "the quick brown" is far more likely
        // than "the quick crown" when reading this particular script.
        for i in 0 ..< max(0, words.count - 2) {
            let phrase = "\(words[i]) \(words[i + 1]) \(words[i + 2])".lowercased()
            data.insert(phraseCount: .init(phrase: phrase, count: 5))
        }

        // Bigrams — lighter 2-word context, covers phrase boundaries missed by trigrams.
        for i in 0 ..< max(0, words.count - 1) {
            let phrase = "\(words[i]) \(words[i + 1])".lowercased()
            data.insert(phraseCount: .init(phrase: phrase, count: 3))
        }

        return data
    }

    // MARK: - Content hashing

    /// FNV-1a hash — fast and stable across app launches (unlike Swift.Hasher).
    nonisolated private static func fnv1aHash(_ words: [String]) -> String {
        var h: UInt64 = 14695981039346656037
        for byte in words.joined(separator: " ").utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return String(h, radix: 16)
    }
}
