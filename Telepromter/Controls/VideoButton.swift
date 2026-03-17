//
//  VideoButton.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 7/2/25.
//

import SwiftUI

struct VideoButton: View {
    @Environment(ContentViewModel.self) var contentVM
    @Environment(VideoCameraViewModel.self) var cameraViewModel
    @Environment(PaywallViewModel.self) var paywallViewModel
    @State private var isPremium = false
    @State private var isMoving = 0.0

    var body: some View {
        @Bindable var paywallViewModel = paywallViewModel
        GeometryReader { geometry in
            let isLandscape = cameraViewModel.deviceOrientation.isLandscape
            let buttonWidth: CGFloat = contentVM.videoOn ? geometry.size.width :
                isLandscape ? 72.0 : 72.0

            VStack {
                Spacer()
                
                HStack {
                    HStack {
                        // VIDEO BUTTON
                        HStack {
                            Button {
                                simpleSuccess()
                                if paywallViewModel.shouldShowPaywall() {
                                    paywallViewModel.isPresented = true
                                } else {
                                    withAnimation(.bouncy) {
                                        isPremium = false
                                        contentVM.videoOn.toggle()
                                        if contentVM.videoOn {
                                            cameraViewModel.checkPermissions()
                                        } else {
                                            // Stop recording cleanly before ending the session
                                            if cameraViewModel.isRecording {
                                                cameraViewModel.stopRecording()
                                            }
                                            cameraViewModel.stopSession()
                                            cameraViewModel.audioLevel = 0.0
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "video")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(contentVM.videoOn ? Color.green : (isPremium ? Color.orange : Color.black))
                                    .padding(.horizontal, 22)
                            }
                        }

                        // Thumbnail + Record controls
                        HStack {
                            HStack {
                                if let thumbnail = cameraViewModel.lastVideoThumbnail,
                                   let url = cameraViewModel.lastVideoLocalURL {
                                    Button {
                                        withAnimation(.easeInOut(duration: 2)) {
                                            cameraViewModel.openInPhotosApp(videoURL: url)
                                        }
                                    } label: {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 15))
                                            .allowsHitTesting(contentVM.videoOn)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .foregroundStyle(.ultraThinMaterial)
                                        )
                                }
                            }
                            .frame(width: geometry.size.width * 0.2)

                            Spacer()

                            // Record button
                            Button {
                                withAnimation(.easeInOut(duration: 1)) {
                                    if contentVM.videoOn {
                                        if cameraViewModel.isRecording {
                                            // Stop recording — pause scrolling if active
                                            if contentVM.isPlaying {
                                                contentVM.isPlaying = false
                                            }
                                            cameraViewModel.stopRecording()
                                        } else {
                                            cameraViewModel.startRecording()
                                        }
                                    }
                                }
                            } label: {
                                //Countdown numbers
                                
                                if let countdownValue = cameraViewModel.countdown {
                                    Text("\(countdownValue)")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                        .padding()
                                } else {
                                    
                                    Image(systemName: cameraViewModel.isRecording ? "record.circle.fill" : "record.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(cameraViewModel.isRecording ? Color.red : Color.color.text)
                                }
                            }

                            Spacer()

                            // Recording time
                            HStack {
                                Text(timeString(from: cameraViewModel.recordingTime))
                                    .font(.system(size: 25, weight: .semibold, design:.rounded))
                                    .foregroundStyle(cameraViewModel.isRecording ? Color.red : Color.color.text)
                            }
                            .frame(width: geometry.size.width * 0.2)
                        }

                        // Camera switch button
                        HStack {
                            Button {
                                if contentVM.videoOn { cameraViewModel.switchCamera() }
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(Color.color.text)
                                    .padding(.horizontal, 22)
                            }
                        }
                    }
                    .frame(height: 60)
                    .frame(width: buttonWidth, alignment: .leading)
                    .clipped()
                    .applyIfAvailableGlassClear()
                    .overlay {
                        if paywallViewModel.shouldShowPaywall() { premiumTag }
                    }
                }
                .padding(.bottom, 10)
            }
            .sheet(isPresented: $paywallViewModel.isPresented) {
                PaywallView()
            }
        }
    }
}

#Preview {
    VideoButton()
        .environment(ContentViewModel())
        .environment(VideoCameraViewModel())
        .environment(PaywallViewModel())
}

extension View {
    @ViewBuilder
    func applyIfAvailableGlassClear() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(RoundedRectangle(cornerRadius: 30).fill(Color.gray.opacity(0.2)))
        }
    }
}

extension VideoButton {
    var premiumTag: some View {
        Circle()
            .fill(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .bottomLeading, endPoint: .bottomTrailing))
            .frame(width: 18, height: 189)
            .overlay(
                Text("P")
                    .bold()
                    .foregroundStyle(Color.color.background)
                    .font(.caption)
            )
            .offset(x: 20, y: -20)
    }
}
