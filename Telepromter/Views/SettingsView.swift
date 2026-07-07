//
//  SettingsView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/17/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(VideoCameraViewModel.self) var cameraVM
    @Environment(ContentViewModel.self) var contentVM
    @AppStorage("scrollMode") var scrollMode: ScrollMode = .regular
    @AppStorage("themeColor") var themeColor: themeSwitching = .blue
    @AppStorage("showLevelIndicator") var showLevelIndicator: Bool = true
    @State private var opacity: Double = 1

    var body: some View {
        @Bindable var cameraVM = cameraVM
        NavigationStack {
            ZStack {
                BackgroundView()
                    .opacity(0.4)
                VStack {
                    Form {
                        Section {
                            Picker("Resolution", selection: $cameraVM.selectedResolution) {
                                ForEach(VideoResolution.allCases) { res in
                                    Text(res.rawValue).tag(res)
                                        .foregroundStyle(.black)
                                }
                            }
                            Picker("Frame Rate", selection: $cameraVM.selectedFrameRate) {
                                ForEach(cameraVM.supportedFrameRates) { rate in
                                    Text("\(rate.rawValue) fps").tag(rate)
                                        .foregroundStyle(.black)
                                }
                            }
                        } header: {
                            Text("Video Settings")
                                .font(.callout)
                        }

                        Section {
                            Toggle(isOn: $cameraVM.countdownOnOff) {
                                Text("Recording Count Down")
                            }
                            Picker(selection: $cameraVM.selectedCountdown, label: Text("Select Duration")) {
                                ForEach(1...15, id: \.self) {
                                    Text("\($0) seconds")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 60)
                            
                            Toggle(isOn: $showLevelIndicator) {
                                Text("Level Indicator")
                            }
                            
                            Picker("Scroll Mode", selection: $scrollMode) {
                                Text("Regular").tag(ScrollMode.regular)
                                Text("In Line").tag(ScrollMode.inLine)
                                Text("Voice").tag(ScrollMode.voice)
                            }
                            .pickerStyle(.segmented)
                            Text("Regular — flowing text. In Line — one word per line. Voice — text follows your speech (video mode only).")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            
                        } header: {
                            Text("General")
                                .font(.callout)
                        }
                        
                        Section {
                            VStack(alignment: .center) {
                                HStack {
                                    ForEach(themeSwitching.allCases, id: \.self) { row in
                                        RoundedRectangle(cornerRadius: 50)
                                            .frame(width: 50, height: 24)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [row.colorTop, row.colorBottom],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .padding(5)
                                            .simultaneousGesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { _ in
                                                        withAnimation {
                                                            simpleSuccess()
                                                            themeColor = row
                                                            opacity = 0.0
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        withAnimation { opacity = 1.0 }
                                                    }
                                            )
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            Text("Long press for a quick preview of the background color")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        } header: {
                            Text("Background Color")
                                .font(.callout)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .opacity(opacity)
                    .tint(.primary)
                }
                .navigationTitle("Settings")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(VideoCameraViewModel())
        .environment(ContentViewModel())
}
