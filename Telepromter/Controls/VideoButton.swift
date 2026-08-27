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
    @State private var showSavedLabel = false
    @State private var opacity: Double = 1.0
    @State private var speedOpacity: Double = 0.0
    
    @AppStorage("textSize") private var textSize: Int = 4
    @AppStorage("speedValue") private var speedValue: Double = 3
    @AppStorage("scrollMode") private var scrollMode: ScrollMode = .regular
    
    @Binding var fontSpeedBar: Bool
    
    
    var body: some View {
        @Bindable var paywallViewModel = paywallViewModel
        @Bindable var cameraViewModel = cameraViewModel
        GeometryReader { geometry in
            let isLandscape = cameraViewModel.deviceOrientation.isLandscape
            let buttonWidth: CGFloat = contentVM.videoOn ? geometry.size.width :
            isLandscape ? 72.0 : 0.0
            let hasZoomOptions = !cameraViewModel.isFrontCamera && !cameraViewModel.availableZoomOptions.isEmpty
            let buttonHeight: CGFloat = contentVM.videoOn ? (hasZoomOptions ? 160 : 120) : 0
            
            VStack(alignment: .leading) {
                Spacer()
                
                // SIZE AND SPEED OF TEXT SECTION ========================================================
                HStack {
                    HStack {
                        HStack {
                            // Plus button — increase text size
                            Button {
                                withAnimation(.smooth) {
                                    simpleSuccess()
                                    textSize = min(textSize + 1, 10)
                                    contentVM.fontSize = Double(textSize * 10)
                                    opacity = 0.3
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation(.smooth) { opacity = 0.0 }
                                }
                            } label: {
                                Text("+")
                                    .font(.system(size: 25))
                                    .bold()
                                    .foregroundStyle(Color.color.text)
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(textSize >= 10)
                            
                            Text("\(textSize)")
                                .font(.system(size: 35))
                                .frame(width: 54)
                                .bold()
                                .opacity(1)
                                .foregroundStyle(textSize >= 10 ? .orange : Color.color.text)
                            
                            // Minus button — decrease text size
                            Button {
                                withAnimation(.smooth) {
                                    simpleSuccess()
                                    textSize = max(textSize - 1, 1)
                                    contentVM.fontSize = Double(textSize * 10)
                                    opacity = 1
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation(.smooth) { opacity = 0.0 }
                                }
                            } label: {
                                Text("-")
                                    .font(.system(size: 40))
                                    .bold()
                                    .foregroundStyle(Color.color.text)
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(textSize <= 1)
                            
                            
                        }
                        
                        Spacer()
                        
                        HStack{
                            Image(systemName: "textformat.size")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)

                            Divider()

                            Image(systemName: "figure.run")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)

                        }.onTapGesture {
                            withAnimation(.bouncy) { fontSpeedBar.toggle() }
                        }
                        .modifier(TextSizeSpeedTipModifier())
                        
                        Spacer()
                        
                        HStack {
                            // Minus button — decrease speed
                            Button {
                                simpleSuccess()
                                withAnimation(.smooth) {
                                    speedValue = max(round(speedValue) - 1, 1)
                                    contentVM.scrollSpeed = Double(speedValue * 5)
                                    speedOpacity = 0.8
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(0.3))
                                    withAnimation(.smooth) { speedOpacity = 0.3 }
                                }
                            } label: {
                                Text("-")
                                    .font(.system(size: 40))
                                    .bold()
                                    .foregroundStyle(Color.color.text)
                                    .frame(width: 30, height: 30)
                            }
                            .disabled(round(speedValue) <= 1)

                            Text("\(Int(round(speedValue)))")
                                .font(.system(size: 35))
                                .frame(width: 54)
                                .bold()
                                .opacity(1)
                                .foregroundStyle(round(speedValue) >= 10 ? .orange : Color.color.text)

                            // Plus button — increase speed
                            Button {
                                simpleSuccess()
                                withAnimation(.smooth) {
                                    speedValue = min(round(speedValue) + 1, 10)
                                    contentVM.scrollSpeed = Double(speedValue * 5)
                                    speedOpacity = 0.8
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(0.3))
                                    withAnimation(.smooth) { speedOpacity = 0.3 }
                                }
                            } label: {
                                Text("+")
                                    .font(.system(size: 25))
                                    .bold()
                                    .foregroundStyle(Color.color.text)
                                    .frame(width: 30, height: 30)
                            }
                            .padding(.vertical, 4)
                            .disabled(round(speedValue) >= 10)
                        }
                        // Speed controls disabled in voice mode — speech pace drives scrolling
                        .opacity(scrollMode == .voice ? 0.35 : 1)
                        .disabled(scrollMode == .voice)
                    }
                    .frame(width: fontSpeedBar ? geometry.size.width - 30 : 48, height: 25)
                    .padding(15)
                    .applyIfAvailableGlassClear()
                    .cornerRadius(30)
                  
                    
                    Spacer()
                }
                // SIZE AND SPEED OF TEXT SECTION END ========================================================
                
                
                //VIDEO BUTTON ON/OFF
                Button {
                    simpleSuccess()
                    if paywallViewModel.shouldShowPaywall() {
                        paywallViewModel.isPresented = true
                    } else {
                        withAnimation(.bouncy) {
                            isPremium = false
                            contentVM.videoOn.toggle()
                            if !contentVM.videoOn {
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
                        .foregroundStyle(contentVM.videoOn ? Color.green : (isPremium ? Color.orange : Color.color.text))
                        .frame(width: 78, height: 55)
                }
                .contentShape(Rectangle())
                .frame(width: 78, height: 55, alignment: .center)
                .applyIfAvailableGlassClear()
                .overlay {
                    if paywallViewModel.shouldShowPaywall() { premiumTag }
                }
                .modifier(VideoModeTipModifier())

                //VIDEO BUTTON ON/OFF END
                
                HStack {
                    VStack{
                        HStack{
                        // Countdown numbers
                        if let countdownValue = cameraViewModel.countdown {
                            Text("\(countdownValue)")
                                .font(.system(size: 35, weight: .semibold, design:.rounded))
                                .foregroundColor(.red)
                            
                        } else {
                            // Timer clock
                            Text(timeString(from: cameraViewModel.recordingTime))
                                .font(.system(size: 35, weight: .semibold, design:.rounded))
                                .foregroundStyle(cameraViewModel.isRecording ? Color.red : Color.color.text)
                        }
                    }
                        .frame(height: 30)
                       
                        ZStack {
                            Capsule()
                                .stroke(lineWidth: 0.5)
                                .fill(.secondary.opacity(0.25))
                                .frame(height: 3)
                                
                            LinearGradient(
                                colors: [.orange, .green, .green, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 1.5)
                            .clipShape(Capsule())
                            .scaleEffect(x: CGFloat(min(Double(cameraViewModel.audioLevel), 1.0)), y: 1, anchor: .center)
                            .blur(radius: 1)
                        }
                        .clipped()
                        .padding(.horizontal, 20)
                        .animation(.easeOut(duration: 0.3), value: cameraViewModel.audioLevel)
                            
                        // Zoom buttons — back camera only
                        if !cameraViewModel.isFrontCamera && !cameraViewModel.availableZoomOptions.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(cameraViewModel.availableZoomOptions) { option in
                                    Button {
                                        cameraViewModel.setZoom(option.factor)
                                    } label: {
                                        let isSelected = abs(cameraViewModel.selectedZoomFactor - option.factor) < 0.01
                                        Text(option.label)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.black : Color.color.text)
                                            .frame(width: 40, height: 28)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? Color.yellow.opacity(0.9) : Color.clear)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        HStack(spacing: 30){

                            // Resolution + FPS picker
                            Menu {
                                ForEach(VideoResolution.allCases) { res in
                                    Button {
                                        cameraViewModel.selectedResolution = res
                                        cameraViewModel.restartSession()
                                    } label: {
                                        if cameraViewModel.selectedResolution == res {
                                            Label(res.label, systemImage: "checkmark")
                                        } else {
                                            Text(res.label)
                                        }
                                    }
                                }
                                Divider()
                                ForEach(cameraViewModel.supportedFrameRates) { rate in
                                    Button {
                                        cameraViewModel.selectedFrameRate = rate
                                    } label: {
                                        if cameraViewModel.selectedFrameRate == rate {
                                            Label("\(rate.rawValue) fps", systemImage: "checkmark")
                                        } else {
                                            Text("\(rate.rawValue) fps")
                                        }
                                    }
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 12)
                                    .foregroundStyle(.clear)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        VStack(spacing: -1) {
                                            Text(cameraViewModel.selectedResolution.label)
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                            Text("\(cameraViewModel.selectedFrameRate.rawValue)")
                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundStyle(Color.color.text)
                                    }
                            }
                            .disabled(cameraViewModel.isRecording)
                            
                            
                            if contentVM.videoOn {
                                // Thumbnail + Record controls
                                
                                if cameraViewModel.isSavingVideo {
                                    VStack(spacing: 3) {
                                        ProgressView()
                                            .tint(Color.color.text)
                                            .frame(width: 30, height: 30)
                                        Text("Saving")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.color.text)
                                    }
                                    .frame(width: 45, height: 45)
                                } else if let thumbnail = cameraViewModel.lastVideoThumbnail,
                                   let url = cameraViewModel.lastVideoLocalURL {
                                    Button {
                                        showSavedLabel = false
                                        cameraViewModel.openInPhotosApp(videoURL: url)
                                    } label: {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 45, height: 45)
                                            .clipShape(RoundedRectangle(cornerRadius: 15))
                                            .allowsHitTesting(contentVM.videoOn)
                                    }
                                    .popover(isPresented: $showSavedLabel, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                                        Text("Video saved to Photos")
                                            .font(.caption)
                                            .padding()
                                            .presentationCompactAdaptation(.popover)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 45, height: 45)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .foregroundStyle(.ultraThinMaterial)
                                        )
                                }
                                
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
                                    Image(systemName: cameraViewModel.isRecording ? "circle.fill" : "circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 55, height: 55)
                                        .foregroundColor(cameraViewModel.isRecording ? Color.red : Color.color.text)
                                }
                                
                                
                                
                                // Aspect ratio picker
                                Menu {
                                    Button {
                                        cameraViewModel.showAspectGuides.toggle()
                                    } label: {
                                        Label(
                                            cameraViewModel.showAspectGuides ? "Hide Guides" : "Show Guides",
                                            systemImage: cameraViewModel.showAspectGuides ? "rectangle.dashed.badge.record" : "rectangle.dashed"
                                        )
                                    }
                                    Divider()
                                    ForEach(VideoAspectRatio.allCases) { ratio in
                                        Button {
                                            cameraViewModel.selectedAspectRatio = ratio
                                        } label: {
                                            if cameraViewModel.selectedAspectRatio == ratio {
                                                Label(ratio.label, systemImage: "checkmark")
                                            } else {
                                                Text(ratio.label)
                                            }
                                        }
                                    }
                                } label: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .foregroundStyle(.clear)
                                        .frame(width: 45, height: 45)
                                        .overlay {
                                            Text(cameraViewModel.selectedAspectRatio.label)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color.color.text)
                                        }
                                }
                                .disabled(cameraViewModel.isRecording)
                                
                                
                                // Front/Back camera switch button
                                Button {
                                    cameraViewModel.switchCamera()
                                } label: {
                                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(Color.color.text)
                                }
                            } else {
                                Spacer()
                            }
                        }
                        
                    }
                    
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasZoomOptions)
                .frame(width: buttonWidth, height: buttonHeight, alignment: .leading)
                .clipped()
                .applyIfAvailableGlassClear()
                
            }
            .sheet(isPresented: $paywallViewModel.isPresented) {
                PaywallView()
            }
            .onChange(of: cameraViewModel.videoSavedToPhotos) { _, saved in
                guard saved else { return }
                showSavedLabel = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    showSavedLabel = false
                    cameraViewModel.videoSavedToPhotos = false
                }
            }
        }
    }
}

#Preview {
    VideoButton(fontSpeedBar: .constant(true))
        .environment(ContentViewModel())
        .environment(VideoCameraViewModel())
        .environment(PaywallViewModel())
        .environment(VoiceScrollViewModel())
}

extension View {
    @ViewBuilder
    func applyIfAvailableGlassClear() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.2)))
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
