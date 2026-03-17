//
//  PrompterView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.

import SwiftUI

// MARK: - Effect: wraps vertical offset; reports *live* Y each frame
fileprivate struct TeleprompterMarquee: GeometryEffect {
    var progress: CGFloat
    var baseOffset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
    // Called each frame with the current on-screen Y and scroll fraction.
    // Uses a class-wrapper so SwiftUI doesn't try to diff/animate this property.
    var onUpdate: OnUpdateWrapper
    
    final class OnUpdateWrapper {
        let call: (_ yNow: CGFloat, _ fraction: CGFloat) -> Void
        init(_ call: @escaping (_ yNow: CGFloat, _ fraction: CGFloat) -> Void) {
            self.call = call
        }
    }
    
    var animatableData: CGFloat {
        get { progress }
        set {
            progress = newValue
            let distance = containerHeight + contentHeight
            guard distance > 0 else { return }
            let yNow = wrappedYOffset
            let scrolled = containerHeight - yNow
            let fraction = min(max(scrolled / distance, 0), 1)
            onUpdate.call(yNow, fraction)
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
    @Binding var scrollProgress: Double
    
    @State private var animProgress: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    // liveY is written from the GeometryEffect callback via DispatchQueue.main.async
    // to avoid "modifying state during view update".
    @State private var liveY: CGFloat = 0
    
    // Changing this ID cancels the repeatForever by rebuilding the animated subtree.
    // We capture liveY into frozenY before changing it so the new subtree starts at
    // the correct position instead of the reset-to-zero @State default.
    @State private var animationID = UUID()
    @State private var frozenY: CGFloat = 0   // liveY captured just before ID change

    @State private var isDragging = false
    @State private var lastDragTranslation: CGFloat = 0
    
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
                }
                .onChange(of: geometry.size.height, initial: false) { _, newH in
                    contentVM.textInputWindowHeight = newH
                    if contentVM.isPlaying {
                        retimeAnimationAtLiveY()
                    } else {
                        updateScrollProgress()
                    }
                }
        }
    }
    
    // MARK: - Animated content
    
    private var animatedStack: some View {
        VStack {
            Group {
                if inLine {
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
                    baseOffset: baseOffset,
                    contentHeight: contentVM.textContentHeight,
                    containerHeight: contentVM.textInputWindowHeight,
                    onUpdate: .init { yNow, fraction in
                        // Defer state writes out of the render pass
                        DispatchQueue.main.async {
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
                        let minY = -contentVM.textContentHeight
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
                    retimeAnimationAtLiveY()
                }
            }
            .onChange(of: contentVM.textContentHeight, initial: false) { _, _ in
                if contentVM.isPlaying {
                    retimeAnimationAtLiveY()
                } else {
                    updateScrollProgress()
                }
            }
            // Runs once after .id(animationID) rebuilds the subtree.
            // At this point @State vars are reset, so we restore from frozenY.
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
    
    // MARK: - Animation control
    
    private func currentAnimation() -> Animation {
        let distance = max(contentVM.textInputWindowHeight + contentVM.textContentHeight, 1)
        let pointsPerSecond = max(CGFloat(contentVM.scrollSpeed) * 5, 1)
        let duration = Double(distance / pointsPerSecond)
        return .linear(duration: duration).repeatForever(autoreverses: false)
    }
    
    private func startPlayingFromLiveY() {
        // Capture current Y before the ID change resets @State
        frozenY = liveY
        // Rebuild subtree to cancel any in-flight repeatForever
        animationID = UUID()
        // onAppear of the new subtree will set baseOffset = frozenY, animProgress = 0.
        // Then kick the animation.
        DispatchQueue.main.async {
            withAnimation(currentAnimation()) {
                animProgress = 1
            }
        }
    }
    
    private func pauseFreezeAtLiveY() {
        frozenY = liveY
        animationID = UUID()
        // onAppear restores baseOffset/animProgress; yOffset kept in sync here
        contentVM.yOffset = liveY
        updateScrollProgress()
    }
    
    private func retimeAnimationAtLiveY() {
        frozenY = liveY
        animationID = UUID()
        DispatchQueue.main.async {
            withAnimation(currentAnimation()) {
                animProgress = 1
            }
        }
    }
}


#Preview {
    PrompterView(scrollProgress: .constant(0)).environmentObject(ContentViewModel())
}
