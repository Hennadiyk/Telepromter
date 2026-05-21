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
    
    @AppStorage("textSize") private var textSize: Int = 3
    @AppStorage("speedValue") private var speedValue: Double = 2.5
   
    @Binding var fontSpeedBar: Bool


    var body: some View {
        @Bindable var paywallViewModel = paywallViewModel
        GeometryReader { geometry in
            let isLandscape = cameraViewModel.deviceOrientation.isLandscape
            let buttonWidth: CGFloat = contentVM.videoOn ? geometry.size.width :
                isLandscape ? 72.0 : 0.0
            let buttonHeight: CGFloat = contentVM.videoOn ? 120 : 0

            VStack(alignment: .leading) {
                Spacer()
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
                            
                            Spacer()
                            
                            Image(systemName: "textformat.size")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)
                                .onTapGesture {
                                    withAnimation(.bouncy) { fontSpeedBar.toggle() }
                                }
                        }
                        
                        Divider()
                            .onTapGesture {
                                withAnimation(.bouncy) { fontSpeedBar.toggle() }
                            }
                        
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)
                                .onTapGesture {
                                    withAnimation(.bouncy) { fontSpeedBar.toggle() }
                                }
                            
                            // Minus button — decrease speed
                            Button {
                                simpleSuccess()
                                withAnimation(.smooth) {
                                    speedValue = max(speedValue - 0.5, 0.5)
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
                            
                            Text(String(format: "%.1f", speedValue))
                                .font(.system(size: 35))
                                .frame(width: 54)
                                .bold()
                                .opacity(1)
                                .foregroundStyle(speedValue >= 6 ? .orange : Color.color.text)
                            
                            // Plus button — increase speed
                            Button {
                                withAnimation(.smooth) {
                                    simpleSuccess()
                                    speedValue = min(speedValue + 0.5, 6)
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
                            .disabled(speedValue >= 6)
                        }
                    }
                    .frame(width: fontSpeedBar ? 340 : 48, height: 25)
                    .padding(12)
                    .applyIfAvailableGlassClear()
                    .cornerRadius(30)
                    
                    Spacer()
                }
                HStack{
                // VIDEO BUTTON
                Button {
                    simpleSuccess()
                    if !paywallViewModel.shouldShowPaywall() {
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
                        .foregroundStyle(contentVM.videoOn ? Color.green : (isPremium ? Color.orange : Color.black))
                        
                       
                }
                }
                .frame(width: 72, height: 60, alignment: .center)
                    .applyIfAvailableGlassClear()
                    .overlay {
                        if paywallViewModel.shouldShowPaywall() { premiumTag }
                    }
               
                HStack {
                    VStack{
                    // Timer clock
                        //Countdown numbers
                        if let countdownValue = cameraViewModel.countdown {
                            Text("\(countdownValue)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                
                        } else {
                            
                            Text(timeString(from: cameraViewModel.recordingTime))
                                .font(.system(size: 25, weight: .semibold, design:.rounded))
                                .foregroundStyle(cameraViewModel.isRecording ? Color.red : Color.color.text)
                        }
                        
                        Divider()
                            .padding(.horizontal, 60)
                        
                        HStack(spacing: 20){
                        
                        // Quality placeholder
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: 45, height: 45)
                        
                        
                        if contentVM.videoOn {
                            // Thumbnail + Record controls
                           
                                if let thumbnail = cameraViewModel.lastVideoThumbnail,
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
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(cameraViewModel.isRecording ? Color.red : Color.color.text)
                                }

                               

                                // Aspect Ratio placeholder
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: 45, height: 45)
                           

                            // Front/Back camera switch button
                            Button {
                                cameraViewModel.switchCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 45, height: 45)
                                    .foregroundColor(Color.color.text)
                            }
                        } else {
                            Spacer()
                        }
                    }
                  
                  
                    }
                    .frame(width: buttonWidth, height: buttonHeight, alignment: .leading)
                    .clipped()
                    .applyIfAvailableGlassClear()
                }
                //.padding(.bottom, 10)
               
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
