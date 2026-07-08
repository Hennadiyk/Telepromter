//
//  ContentView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/30/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoCameraViewModel.self) private var cameraViewModel
    @Environment(ContentViewModel.self) private var contentViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
    @AppStorage("appFirstLaunchDate") private var appFirstLaunchDate: Double = 0
    @AppStorage("hasRatedOrReviewed") private var hasRatedOrReviewed: Bool = false
    @AppStorage("reviewLastDismissedDate") private var reviewLastDismissedDate: Double = 0
    @State private var showReviewPopup = false

    var body: some View {
        ZStack {
            if isOnboardingComplete {
                @Bindable var contentViewModel = contentViewModel
                TabView(selection: $contentViewModel.selectedTab) {
                    Tab("Add Text", systemImage: "character.cursor.ibeam", value: 0) {
                        TextInputView()
                    }.badge(.zero)

                    Tab("Teleprompter", systemImage: "text.aligncenter", value: 1) {
                        ControlsView()
                            .toolbar(contentViewModel.videoOn ? .hidden : .visible, for: .tabBar)
                    }

                    Tab("Account", systemImage: "circle.fill", value: 2, role: UIDevice.isIPad ? .none : .search) {
                        AccountDetailsView()
                    }
                }
            } else {
                OnboardingView()
            }

            if showReviewPopup {
                ReviewView(isPresented: $showReviewPopup)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    .zIndex(1)
            }
        }
        .tint(Color.color.gradientHigh)
        .onChange(of: contentViewModel.isPlaying) { _, _ in updateIdleTimer() }
        .onChange(of: cameraViewModel.isRecording) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkReviewTrigger() }
        }
        .onAppear {
            recordFirstLaunchIfNeeded()
            checkReviewTrigger()
            updateIdleTimer()
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = contentViewModel.isPlaying || cameraViewModel.isRecording
    }

    private func recordFirstLaunchIfNeeded() {
        if appFirstLaunchDate == 0 {
            appFirstLaunchDate = Date().timeIntervalSince1970
        }
    }

    private func checkReviewTrigger() {
        guard isOnboardingComplete, !hasRatedOrReviewed, !showReviewPopup else { return }
        let now = Date().timeIntervalSince1970
        guard now - appFirstLaunchDate >= 3 * 24 * 3600 else { return }
        let fiveDays: Double = 5 * 24 * 3600
        guard reviewLastDismissedDate == 0 || now - reviewLastDismissedDate >= fiveDays else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard !hasRatedOrReviewed else { return }
            showReviewPopup = true
        }
    }
}

#Preview {
    ContentView()
        .environment(VideoCameraViewModel())
        .environment(ContentViewModel())
        .environment(PaywallViewModel())
        .environment(VoiceScrollViewModel())
}
