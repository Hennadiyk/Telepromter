//
//  PrompterView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.

import SwiftUI

// MARK: - Effect: wraps vertical offset; reports *live* Y each frame
fileprivate struct TeleprompterMarquee: GeometryEffect {
    var progress: CGFloat           // 0 → 1 = one full travel (container + content)
    var baseOffset: CGFloat         // anchor Y at (re)start or pause
    var contentHeight: CGFloat
    var containerHeight: CGFloat
    var onUpdate: (_ yNow: CGFloat, _ fraction: CGFloat) -> Void  // live Y + progress
    
    var animatableData: CGFloat {
        get { progress }
        set {
            progress = newValue
            
            let distance = containerHeight + contentHeight
            guard distance > 0 else { return }
            let yNow = wrappedYOffset
            let startOffset = containerHeight
            let scrolled = startOffset - yNow
            let fraction = min(max(scrolled / distance, 0), 1)
            
            let cb = onUpdate
            DispatchQueue.main.async { cb(yNow, fraction) }
        }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 0, y: wrappedYOffset))
    }
    
    private var wrappedYOffset: CGFloat {
        let distance = containerHeight + contentHeight
        guard distance > 0 else { return baseOffset }
        return wrap(baseOffset - progress * distance,
                    min: -contentHeight,
                    max: containerHeight)
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
    @EnvironmentObject var contentVM: ContentViewModel
    @AppStorage("inLine") private var inLine: Bool = false
    
    // Animation drivers
    @State private var animProgress: CGFloat = 0          // driven 0→1 repeatedly
    @State private var baseOffset: CGFloat = 0            // anchor Y for the effect
    @State private var liveY: CGFloat = 0                 // updated by the effect every frame
    
    // Cancels any in‑flight repeatForever by rebuilding the subtree
    @State private var animationInstanceID = UUID()
    
    // Tracks whether a drag gesture is currently active
    @State private var isDragging = false
    // Last translation seen, so we can compute per-frame deltas
    @State private var lastDragTranslation: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            animatedStack
                .id(animationInstanceID) // <- hard-cancel any existing animation when we change this
                .onAppear {
                    contentVM.textInputWindowHeight = geometry.size.height
                    contentVM.yOffset = 0
                    baseOffset = 0
                    liveY = 0
                    contentVM.initialDragOffset = 0
                    contentVM.updateProgress()
                }
                .onChange(of: geometry.size.height, initial: false) { _, newH in
                    contentVM.textInputWindowHeight = newH
                    if contentVM.isPlaying {
                        retimeAnimationAtLiveY()
                    } else {
                        contentVM.updateProgress()
                    }
                }
        }
    }
    
    // MARK: - Animated content
    
    private var animatedStack: some View {
        VStack {
            // ---- Content (Inline OR Paragraph) ----
            Group {
                if inLine {
                    LazyVStack(alignment: .center, spacing: 8) {
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
            // Measure total content height (affects travel distance)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { contentVM.textContentHeight = g.size.height }
                        .onChange(of: g.size.height) { _, newH in
                            contentVM.textContentHeight = newH
                        }
                }
            )
            // Apply the marquee effect and receive live Y each tick
            .modifier(
                TeleprompterMarquee(
                    progress: animProgress,
                    baseOffset: baseOffset,
                    contentHeight: contentVM.textContentHeight,
                    containerHeight: contentVM.textInputWindowHeight,
                    onUpdate: { yNow, fraction in
                        contentVM.progress = Double(fraction)
                        liveY = yNow
                    }
                )
            )
            .clipped()
            // Dragging pauses and lets you reposition, then resume from there
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if contentVM.isPlaying {
                            contentVM.isPlaying = false
                            pauseFreezeAtLiveY()                // freeze exactly where it is
                            isDragging = true
                            lastDragTranslation = value.translation.height
                        } else if !isDragging {
                            // First event of a new paused drag
                            isDragging = true
                            lastDragTranslation = value.translation.height
                        }
                        // Use delta so position tracks finger continuously in the same gesture
                        let delta = value.translation.height - lastDragTranslation
                        lastDragTranslation = value.translation.height
                        let proposed = contentVM.yOffset + delta
                        let minY = -contentVM.textContentHeight
                        let maxY = contentVM.textInputWindowHeight
                        contentVM.yOffset = min(max(proposed, minY), maxY)
                        contentVM.initialDragOffset = contentVM.yOffset
                        baseOffset = contentVM.yOffset
                        liveY = contentVM.yOffset
                        contentVM.updateProgress()
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragTranslation = 0
                    }
            )
            .onChange(of: contentVM.isPlaying, initial: false) { _, playing in
                if playing {
                    startPlayingFromLiveY()
                } else {
                    pauseFreezeAtLiveY()
                }
            }
            .onChange(of: contentVM.scrollSpeed, initial: false) { _, _ in
                if contentVM.isPlaying {
                    // LIVE speed change: retime immediately without moving
                    retimeAnimationAtLiveY()
                }
            }
            .onChange(of: contentVM.textContentHeight, initial: false) { _, _ in
                // Layout changed (font/text): keep position; if playing, retime
                if contentVM.isPlaying {
                    retimeAnimationAtLiveY()
                } else {
                    contentVM.updateProgress()
                }
            }
        }
    }
    
    // MARK: - Animation control
    
    private func travelDistance() -> CGFloat {
        contentVM.textInputWindowHeight + contentVM.textContentHeight
    }
    
    private func currentAnimation() -> Animation {
        let distance = max(travelDistance(), 1)
        // Keep your original feel: points/sec ≈ scrollSpeed * 5
        let pointsPerSecond = max(CGFloat(contentVM.scrollSpeed) * 5, 1)
        let duration = Double(distance / pointsPerSecond)
        return .linear(duration: duration).repeatForever(autoreverses: false)
    }
    
    /// Start/resume from the exact on-screen Y (no jump), canceling any prior animation instance.
    private func startPlayingFromLiveY() {
        // Cancel any existing repeatForever by rebuilding the subtree
        animationInstanceID = UUID()
        // Anchor and reset driver without animation, then kick the repeat
        withAnimation(.none) {
            baseOffset = liveY
            animProgress = 0
        }
        withAnimation(currentAnimation()) {
            animProgress = 1
        }
    }
    
    /// Pause and freeze *exactly* at the current frame’s Y, and cancel any prior animation.
    private func pauseFreezeAtLiveY() {
        // Cancel any existing repeatForever by rebuilding the subtree
        animationInstanceID = UUID()
        withAnimation(.none) {
            contentVM.yOffset = liveY
            baseOffset = liveY
            animProgress = 0
        }
        // progress already synced via onUpdate
    }
    
    /// Live speed update while playing: retime without any visible shift.
    private func retimeAnimationAtLiveY() {
        // Rebuild the subtree to cancel the old repeatForever
        animationInstanceID = UUID()
        // Freeze visually at the current frame…
        withAnimation(.none) {
            baseOffset = liveY
            animProgress = 0
        }
        // …and immediately start again with the new duration at the same Y.
        withAnimation(currentAnimation()) {
            animProgress = 1
        }
    }
}


#Preview {
    PrompterView().environmentObject(ContentViewModel())
}
