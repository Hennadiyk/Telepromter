//
//  PrompterView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.

import SwiftUI

// MARK: - Effect: wraps vertical offset; reports *live* Y each frame
fileprivate struct TeleprompterMarquee: GeometryEffect {
    var progress: CGFloat
    // Wrapped in a class so SwiftUI sees a reference type and excludes these
    // from animatableData synthesis — prevents "invalid sample" timeline warnings.
    var onUpdate: OnUpdateWrapper

    final class OnUpdateWrapper {
        let call: (_ yNow: CGFloat, _ fraction: CGFloat) -> Void
        var baseOffset: CGFloat
        var contentHeight: CGFloat
        var containerHeight: CGFloat
        init(
            baseOffset: CGFloat,
            contentHeight: CGFloat,
            containerHeight: CGFloat,
            _ call: @escaping (_ yNow: CGFloat, _ fraction: CGFloat) -> Void
        ) {
            self.baseOffset = baseOffset
            self.contentHeight = contentHeight
            self.containerHeight = containerHeight
            self.call = call
        }
    }

    var animatableData: CGFloat {
        get { progress }
        set {
            progress = newValue
            let distance = onUpdate.containerHeight + onUpdate.contentHeight
            guard distance > 0 else { return }
            let yNow = wrappedYOffset
            let scrolled = onUpdate.containerHeight - yNow
            let fraction = min(max(scrolled / distance, 0), 1)
            onUpdate.call(yNow, fraction)
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 0, y: wrappedYOffset))
    }

    private var wrappedYOffset: CGFloat {
        let distance = onUpdate.containerHeight + onUpdate.contentHeight
        guard distance > 0 else { return onUpdate.baseOffset }
        return wrap(onUpdate.baseOffset - progress * distance,
                    min: -onUpdate.contentHeight,
                    max: onUpdate.containerHeight)
    }

    private func wrap(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let range = max - min
        if range <= 0 { return min }
        var v = value - min
        v = v.truncatingRemainder(dividingBy: range)
        if v < 0 { v += range }
        return v + min
    }
}

// MARK: - View

struct PrompterView: View {
    @Environment(ContentViewModel.self) var contentVM
    @Environment(VoiceScrollViewModel.self) var voiceScrollVM
    @AppStorage("scrollMode") private var scrollMode: ScrollMode = .regular
    @Binding var scrollProgress: Double

    @State private var animProgress: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    // liveY written from GeometryEffect callback via DispatchQueue.main.async
    // to avoid "modifying state during view update".
    @State private var liveY: CGFloat = 0

    // Changing this ID cancels the repeatForever by rebuilding the animated subtree.
    // frozenY captures liveY before the ID change so the new subtree starts correctly.
    @State private var animationID = UUID()
    @State private var frozenY: CGFloat = 0

    @State private var isDragging = false
    @State private var lastDragTranslation: CGFloat = 0
    @State private var scrollToTopPending = false
    @State private var callbackGeneration: Int = 0

    var body: some View {
        GeometryReader { geometry in
            animatedStack
                .id(animationID)
                .onAppear {
                    contentVM.textInputWindowHeight = geometry.size.height
                    contentVM.yOffset = 0
                    baseOffset = 0
                    liveY = 0
                    frozenY = 0
                    contentVM.initialDragOffset = 0
                    updateScrollProgress()
                    // Auto-start voice recognition when the view appears in voice mode
                    if scrollMode == .voice, !contentVM.textInput.isEmpty, !contentVM.isPlaying {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if !contentVM.isPlaying { contentVM.isPlaying = true }
                        }
                    }
                }
                .onChange(of: geometry.size.height, initial: false) { _, newH in
                    contentVM.textInputWindowHeight = newH
                    if contentVM.isPlaying && scrollMode != .voice {
                        retimeAnimationAtLiveY()
                    } else {
                        updateScrollProgress()
                    }
                }
        }
    }

    // MARK: - Animated content

    private var animatedStack: some View {
        let callbackGen = callbackGeneration
        return VStack {
            Group {
                if scrollMode == .inLine || scrollMode == .voice {
                    VStack(alignment: .center, spacing: 8) {
                        ForEach(contentVM.words.indices, id: \.self) { idx in
                            Text(contentVM.words[idx])
                                .font(.custom("Arial", size: 20 + contentVM.fontSize / 4))
                        }
                    }
                } else {
                    Text(contentVM.textInput)
                        .font(.custom("Arial", size: 20 + contentVM.fontSize / 4))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { contentVM.textContentHeight = g.size.height }
                        .onChange(of: g.size.height) { _, newH in
                            contentVM.textContentHeight = newH
                        }
                }
            )
            .modifier(
                TeleprompterMarquee(
                    progress: animProgress,
                    onUpdate: .init(
                        baseOffset: baseOffset,
                        contentHeight: contentVM.textContentHeight,
                        containerHeight: contentVM.textInputWindowHeight
                    ) { yNow, fraction in
                        DispatchQueue.main.async {
                            guard callbackGeneration == callbackGen else { return }
                            liveY = yNow
                            scrollProgress = Double(fraction)
                        }
                    }
                )
            )
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if contentVM.isPlaying {
                            contentVM.isPlaying = false
                            pauseFreezeAtLiveY()
                            isDragging = true
                            lastDragTranslation = value.translation.height
                        } else if !isDragging {
                            isDragging = true
                            lastDragTranslation = value.translation.height
                        }
                        let delta = value.translation.height - lastDragTranslation
                        lastDragTranslation = value.translation.height
                        let proposed = contentVM.yOffset + delta
                        // Keep at least the bottom 20 % of the container's height
                        // worth of text visible, so the user can always grab it
                        // and drag back — prevents the last word from vanishing.
                        let minY = -(contentVM.textContentHeight - contentVM.textInputWindowHeight * 0.2)
                        let maxY = contentVM.textInputWindowHeight
                        contentVM.yOffset = min(max(proposed, minY), maxY)
                        contentVM.initialDragOffset = contentVM.yOffset
                        baseOffset = contentVM.yOffset
                        liveY = contentVM.yOffset
                        frozenY = contentVM.yOffset
                        updateScrollProgress()
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragTranslation = 0
                        // In voice mode, resume recognition from the new scroll position
                        if scrollMode == .voice, !contentVM.textInput.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                if !contentVM.isPlaying { contentVM.isPlaying = true }
                            }
                        }
                    }
            )
            .onChange(of: contentVM.isPlaying, initial: false) { _, playing in
                if playing {
                    if scrollMode == .voice { startVoiceScrollPlayback() }
                    else { startPlayingFromLiveY() }
                } else {
                    if scrollMode == .voice { voiceScrollVM.stop() }
                    // scrollToTopPending is set in the same handler as isPlaying=false,
                    // so SwiftUI batches them — it is already true here when scroll-to-top
                    // was requested, before pauseFreezeAtLiveY() could overwrite frozenY/yOffset.
                    if scrollToTopPending {
                        scrollToTopPending = false
                        callbackGeneration += 1
                        contentVM.yOffset = 0
                        contentVM.initialDragOffset = 0
                        frozenY = 0
                        baseOffset = 0
                        liveY = 0
                        animProgress = 0
                        animationID = UUID()
                        updateScrollProgress()
                        if scrollMode == .voice {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if !contentVM.isPlaying { contentVM.isPlaying = true }
                            }
                        }
                    } else {
                        pauseFreezeAtLiveY()
                    }
                }
            }
            .onChange(of: voiceScrollVM.matchedWordIndex, initial: false) { oldIndex, newIndex in
                guard scrollMode == .voice, contentVM.isPlaying else { return }
                let contentH = contentVM.textContentHeight
                let containerH = contentVM.textInputWindowHeight
                let distance = containerH + contentH
                guard distance > 0, contentH > 0 else { return }
                // Keep the spoken word at vertical center of the window.
                let P = containerH * 0.5
                let totalWords = max(1, contentVM.words.count)
                let wps = max(0.5, voiceScrollVM.wordsPerSecond)
                let wordsDelta = max(1, newIndex - oldIndex)

                // Hard-cap lookahead at 1.5 words so a burst batch never scrolls
                // past many words at once — this is the main cause of "too fast" skipping.
                let lookahead = min(wps * 0.3, 1.5)
                let predictedIndex = min(Double(newIndex) + lookahead, Double(totalWords - 1))
                let predictedProgress = predictedIndex / Double(totalWords)
                let animTarget = (baseOffset + CGFloat(predictedProgress) * contentH - P) / distance
                let clamped = max(animProgress, max(0, animTarget))
                guard clamped > animProgress + 0.00001 else { return }

                // Duration bridges to next batch at current pace; 0.45 s minimum keeps
                // motion smooth rather than choppy between short batches.
                let duration = max(0.45, Double(wordsDelta) / wps + 0.15)
                withAnimation(.linear(duration: duration)) {
                    animProgress = clamped
                }
            }
            .onChange(of: scrollMode, initial: false) { oldMode, newMode in
                if newMode == .voice {
                    // Auto-start recognition when user switches to voice mode
                    if contentVM.isPlaying { contentVM.isPlaying = false }
                    guard !contentVM.textInput.isEmpty else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !contentVM.isPlaying { contentVM.isPlaying = true }
                    }
                } else {
                    if contentVM.isPlaying { contentVM.isPlaying = false }
                    // Full teardown when leaving voice mode — pause() was used during drag
                    // so the engine may still be running; stop() releases it now.
                    if oldMode == .voice { voiceScrollVM.stop() }
                }
            }
            .onChange(of: contentVM.scrollSpeed, initial: false) { _, _ in
                if contentVM.isPlaying && scrollMode != .voice { retimeAnimationAtLiveY() }
            }
            .onChange(of: contentVM.textContentHeight, initial: false) { _, _ in
                if contentVM.isPlaying && scrollMode != .voice {
                    retimeAnimationAtLiveY()
                } else {
                    updateScrollProgress()
                }
            }
            .onChange(of: contentVM.scrollToTopToken, initial: false) { _, _ in
                if contentVM.isPlaying {
                    // isPlaying is changing — set the flag in the SAME handler so SwiftUI
                    // batches both into one render pass. onChange(of: isPlaying) will then
                    // see scrollToTopPending=true and skip pauseFreezeAtLiveY().
                    scrollToTopPending = true
                    contentVM.isPlaying = false
                } else {
                    // Already stopped — onChange(of: isPlaying) won't fire, so reset directly.
                    if scrollMode == .voice { voiceScrollVM.stop() }
                    callbackGeneration += 1
                    contentVM.yOffset = 0
                    contentVM.initialDragOffset = 0
                    frozenY = 0
                    baseOffset = 0
                    liveY = 0
                    animProgress = 0
                    animationID = UUID()
                    updateScrollProgress()
                    if scrollMode == .voice {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if !contentVM.isPlaying { contentVM.isPlaying = true }
                        }
                    }
                }
            }
            // Runs once after .id(animationID) rebuilds the subtree — restore from frozenY
            .onAppear {
                baseOffset = frozenY
                animProgress = 0
            }
        }
    }

    // MARK: - Progress sync

    private func updateScrollProgress() {
        let distance = contentVM.textInputWindowHeight + contentVM.textContentHeight
        guard distance > 0 else { scrollProgress = 0; return }
        let scrolled = contentVM.textInputWindowHeight - contentVM.yOffset
        scrollProgress = Double(min(max(scrolled / distance, 0), 1))
    }

    // MARK: - Regular / InLine animation control

    private func currentAnimation() -> Animation {
        let distance = max(contentVM.textInputWindowHeight + contentVM.textContentHeight, 1)
        let pointsPerSecond = max(CGFloat(contentVM.scrollSpeed) * 5, 1)
        let duration = Double(distance / pointsPerSecond)
        return .linear(duration: duration).repeatForever(autoreverses: false)
    }

    private func startPlayingFromLiveY() {
        frozenY = liveY
        animationID = UUID()
        DispatchQueue.main.async {
            withAnimation(currentAnimation()) { animProgress = 1 }
        }
    }

    private func pauseFreezeAtLiveY() {
        frozenY = liveY
        animationID = UUID()
        contentVM.yOffset = liveY
        updateScrollProgress()
    }

    private func retimeAnimationAtLiveY() {
        frozenY = liveY
        animationID = UUID()
        DispatchQueue.main.async {
            withAnimation(currentAnimation()) { animProgress = 1 }
        }
    }

    // MARK: - Voice scroll control

    private func startVoiceScrollPlayback() {
        // Use contentVM.yOffset — the authoritative drag position set synchronously
        // by the gesture handler. liveY can be briefly overwritten by async callbacks
        // from a prior animation frame between the drag end and this call.
        let capturedY = contentVM.yOffset
        frozenY = capturedY
        animationID = UUID()
        Task {
            let status = voiceScrollVM.authorizationStatus()
            if status == .notDetermined {
                let granted = await voiceScrollVM.requestAuthorization()
                guard granted else { contentVM.isPlaying = false; return }
            } else if status != .authorized {
                contentVM.isPlaying = false
                return
            }
            let contentH = contentVM.textContentHeight
            let containerH = contentVM.textInputWindowHeight
            let totalWords = contentVM.words.count
            guard totalWords > 0, contentH > 0 else {
                voiceScrollVM.start(words: contentVM.words)
                return
            }
            // Visible word range: content runs from -capturedY to (containerH-capturedY)
            // in content coordinates. ±1 word buffer for height estimation imprecision.
            let firstVisible = max(0,
                Int(-capturedY / contentH * Double(totalWords)) - 1)
            let lastVisible  = min(totalWords - 1,
                Int((containerH - capturedY) / contentH * Double(totalWords)) + 1)
            voiceScrollVM.start(words: contentVM.words,
                                firstVisible: firstVisible,
                                lastVisible: lastVisible)
        }
    }

    private func stopVoiceScrollPlayback() {
        voiceScrollVM.stop()
        pauseFreezeAtLiveY()
    }
}

#Preview {
    PrompterView(scrollProgress: .constant(0))
        .environment(ContentViewModel())
        .environment(VoiceScrollViewModel())
}
