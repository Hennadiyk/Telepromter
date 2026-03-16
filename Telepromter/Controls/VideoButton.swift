//
//  VideoButton.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 7/2/25.
//

import SwiftUI

struct VideoButton: View {
    @EnvironmentObject var contentVM: ContentViewModel
    @EnvironmentObject var cameraViewModel: VideoCameraViewModel
    @EnvironmentObject var paywallViewModel: PaywallViewModel
    @State private var isPremium = false
    @State private var isMoving = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = cameraViewModel.deviceOrientation.isLandscape
            
            let buttonWidth: CGFloat = contentVM.videoOn ? geometry.size.width :
            isLandscape ? 72.0 : 72.0  // Consistent fixed size, adapted by size class for larger screens
            
            VStack {
                
                Spacer()
                countDownTag
                
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
                                        .foregroundStyle(contentVM.videoOn ? Color.green : (isPremium ? Color.orange : Color.blue))
                                        .padding(.horizontal, 22)
                                }
                            }
                            //Thumbnail View
                            HStack {
                                // Video Preview thumb
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
                                                .frame(width: 35, height: 35)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .allowsHitTesting(contentVM.videoOn)
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 35, height: 35)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .foregroundStyle(.ultraThinMaterial)
                                            )
                                    }
                                }
                                .frame(width: geometry.size.width * 0.2)
                                
                                Spacer()
                                // Record button
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 1)) {
                                        if contentVM.videoOn {
                                            cameraViewModel.toggleRecording()
                                        }
                                    }
                                }) {
                                    Image(systemName: cameraViewModel.isRecording ? "record.circle.fill" : "record.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 45, height: 45)
                                        .foregroundColor(cameraViewModel.isRecording ? Color.red : Color.color.text)
                                        .padding(8)
                                }
                                
                                Spacer()
                                
                                // Recording time
                                HStack {
                                    Text(timeString(from: cameraViewModel.recordingTime))
                                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(cameraViewModel.isRecording ? Color.red : Color.color.text)
                                }
                                .frame(width: geometry.size.width * 0.2)
                                
                            }
                            // Camera switch button
                            HStack {
                                
                                Button(action: {
                                    if contentVM.videoOn {
                                        cameraViewModel.switchCamera()
                                    }
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(Color.color.text)
                                        .padding()
                                    
                                    
                                }
                                
                            }
                            
                        }
                        .frame(height: 60)
                        .frame(width: buttonWidth, alignment: .leading)
                        
                        .clipped()
                        .applyIfAvailableGlassClear()
                        .overlay {
                            
                            if paywallViewModel.shouldShowPaywall() {
                                premiumTag
                            }
                            
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
        .environmentObject(ContentViewModel())
        .environmentObject(VideoCameraViewModel())
        .environmentObject(PaywallViewModel())
}

extension View {
    @ViewBuilder
    func applyIfAvailableGlassClear() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(RoundedRectangle(cornerRadius: 30)
                .fill(Color.gray.opacity(0.2)))
        }
    }
}

//Premium Tag
extension VideoButton {
    
    var premiumTag: some View {
        
        //Premium tab on VideoButton
        Circle()
            .fill(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .bottomLeading, endPoint: .bottomTrailing))
            .frame(width: 18, height: 189)
        
            .overlay(
                
                Text("P")
                    .bold()
                    .foregroundStyle(Color.color.background)
                    .font(.caption)
                
                
            ).offset(x: 20, y: -20)
    }
    
    // Pre-recording countdown
    var countDownTag: some View {
        Group {
            if let countdownValue = cameraViewModel.countdown {
                Text("\(countdownValue)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding()
            } else {
                EmptyView()
            }
        }
    }
    
}
