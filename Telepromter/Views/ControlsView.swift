//
//  ControlsView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ControlsView: View {
    @EnvironmentObject var contentVM: ContentViewModel
    @EnvironmentObject var cameraViewModel: VideoCameraViewModel
    @State private var currentAmountHeight: CGFloat = 0.0
    @State private var currentAmountWidth: CGFloat = 0.0
    @State private var finalAmountWidth: CGFloat = 300.0
    @State private var finalAmountHeight: CGFloat = 300.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var isDragging = false
    @State private var fontSpeedBar = false
    @State private var showAlert = false
    @State private var hasDragged = false
    @State private var scrollProgress: Double = 0
    

    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                complexSuccess()
            }
            .onEnded { _ in
                withAnimation {
                    lastOffset = offset
                    isDragging = false
                }
                hasDragged = true
            }
        
        let pressGesture = LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                complexSuccess()
                withAnimation {
                    isDragging = true
                }
            }
        
        let combined = pressGesture.sequenced(before: dragGesture)
        
        ZStack {
            if !contentVM.videoOn {
                BackgroundView()
            } else {
                Color.clear
            }
            
            if contentVM.videoOn {
                CameraView(previewLayer: cameraViewModel.previewLayer)
                    .statusBar(hidden: true)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onAppear {
                        cameraViewModel.checkPermissions()
                    }
                    .onDisappear {
                        cameraViewModel.stopSession()
                    }
            }
            
            GeometryReader { geometry in
                VStack(alignment: .trailing) {
                    PrompterView(scrollProgress: $scrollProgress)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .shadow(color: contentVM.videoOn ? .clear : (isDragging ? .black : .white), radius: 40)
                        .scaleEffect(isDragging ? 1.1 : 1)
                        .offset(offset)
                        .gesture(combined)
                        .frame(width: currentAmountWidth > 0 ? currentAmountWidth : finalAmountWidth,
                               height: currentAmountHeight > 0 ? currentAmountHeight : finalAmountHeight)
                       
                    
                    HStack(alignment: .top) {
                        HStack {
                            Button {
                                simpleSuccess()
                                if contentVM.textInput.isEmpty {
                                    showAlert.toggle()
                                    contentVM.selectedTab = 0
                                } else {
                                    contentVM.isPlaying.toggle()
                                    simpleSuccess()
                                }
                            } label: {
                                PlayButton()
                            }
                        }
                        .offset(x: offset.width + 72, y: offset.height + (isDragging ? -33 : -43))
                        .opacity(isDragging ? 0 : 1)
                        .alert(isPresented: $showAlert) {
                            Alert(title: Text("Please enter your text"), message: nil, dismissButton: .default(Text("OK")))
                        }
                        
                        ResizeBar(progress: $scrollProgress)
                            .clipped()
                            .foregroundStyle(Color.color.background)
                            .offset(x: offset.width + (isDragging ? 28 : 18), y: offset.height + (isDragging ? -85 : -86))
                            .opacity(isDragging ? 0 : 1)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        withAnimation(.bouncy(duration: 1)) {
                                            let deltaWidth = value.translation.width
                                            let deltaHeight = value.translation.height
                                            currentAmountWidth = min(max(finalAmountWidth + deltaWidth, 100), geometry.size.width - (UIDevice.isIPad ? 110 : 85))
                                            currentAmountHeight = min(max(finalAmountHeight + deltaHeight, 100), geometry.size.height - (UIDevice.isIPad ? 70 : 12))
                                            contentVM.textInputWindowHeight = currentAmountHeight
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.bouncy(duration: 1)) {
                                            finalAmountWidth = currentAmountWidth
                                            finalAmountHeight = currentAmountHeight
                                            currentAmountWidth = 0
                                            currentAmountHeight = 0
                                        }
                                    }
                            )
                    }
                }
                .opacity(isDragging ? 0.6 : 1)
                
                SpeedSizeButtons(fontSpeedBar: $fontSpeedBar)
                    .padding(.horizontal, 20)
                
                VideoButton()
                    .padding(.horizontal, 20)
                
                
                
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
            .onPreferenceChange(SizePreferenceKey.self) { newSize in
                if !hasDragged {
                    let topPadding: CGFloat = 20.0
                    offset = CGSize(width: (newSize.width - finalAmountWidth) / 2, height: topPadding)
                    lastOffset = offset
                }
            }
        }
        .onTapGesture {
            withAnimation(.bouncy) {
                fontSpeedBar = false
            }
        }
    }
}

#Preview {
    ControlsView()
        .environmentObject(ContentViewModel())
        .environmentObject(VideoCameraViewModel())
        .environmentObject(PaywallViewModel())
}
