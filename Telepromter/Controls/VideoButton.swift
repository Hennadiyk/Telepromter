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
    @State private var isMoving = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
               
                Spacer()
                if let countdownValue = cameraViewModel.countdown {
                Text("\(countdownValue)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.color.background)
                    .padding()
                 }
                
                HStack {
                    HStack {
                        // VIDEO BUTTON
                        HStack {
                            Button {
                                withAnimation(.bouncy) {
                                    contentVM.videoOn.toggle()
                                    if contentVM.videoOn {
                                        cameraViewModel.checkPermissions()
                                    } else {
                                        cameraViewModel.stopSession()
                                    }
                                }
                            } label: {
                                Image(systemName: "video")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(contentVM.videoOn ? Color.green : Color.blue)
                                    .padding()
                            }
                        }
                        
                        Spacer()
                        
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
                                        .fill(Color.gray.opacity(0.2))
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
                                        contentVM.isPlaying = false
                                    }
                                }
                            }) {
                                Image(systemName: cameraViewModel.isRecording ? "record.circle.fill" : "record.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 45, height: 45)
                                    .foregroundColor(cameraViewModel.isRecording ? Color.red : Color.color.background)
                                    .padding(8)
                            }
                            
                            Spacer()
                            
                            // Recording time
                            HStack {
                                Text(timeString(from: cameraViewModel.recordingTime))
                                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(cameraViewModel.isRecording ? Color.red : Color.color.background)
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
                                    .foregroundColor(Color.color.background)
                                    .padding()
                                    
                                
                            }
                        }
                    }
                    .frame(height: 50)
                    .frame(width: contentVM.videoOn ? geometry.size.width : cameraViewModel.deviceOrientation.isLandscape ? geometry.size.width * 0.1 : geometry.size.width * 0.2)
                    .offset(x: contentVM.videoOn ? 0 : cameraViewModel.deviceOrientation.isLandscape ? 238 : 160)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color.gray.opacity(0.2)))
                    .clipped()
                   
                    
                    Spacer()
                }
                .padding(.bottom, 22)
              
            }
        }
    }
    
}

#Preview {
    VideoButton().environmentObject(ContentViewModel()).environmentObject(VideoCameraViewModel())
}
