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
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false

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

                    Tab("Account", systemImage: "person.crop.circle", value: 2, role: UIDevice.isIPad ? .none : .search) {
                        AccountDetailsView()
                    }
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: contentViewModel.isPlaying) { _, _ in updateIdleTimer() }
        .onChange(of: cameraViewModel.isRecording) { _, _ in updateIdleTimer() }
        .onAppear { updateIdleTimer() }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = contentViewModel.isPlaying || cameraViewModel.isRecording
    }
}

#Preview {
    ContentView()
        .environment(VideoCameraViewModel())
        .environment(ContentViewModel())
        .environment(PaywallViewModel())
}
