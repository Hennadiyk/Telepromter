//
//  SettingsView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/17/24.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var cameraVM: VideoCameraViewModel
    @EnvironmentObject var contentVM: ContentViewModel
    @AppStorage("inLine") var inLine: Bool = false
    @AppStorage("themeColor") var themeColor: themeSwitching = .teal
    @State private var opacity: Double = 1
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                    .opacity(0.4)
                VStack {
                    Form {
                        Section {
                            Picker(
                                "Resolution",
                                selection: $cameraVM.selectedResolution
                            ) {
                                ForEach(VideoResolution.allCases) { res in
                                    Text(res.rawValue).tag(res)
                                }
                            }
                            
                            Picker(
                                "Frame Rate",
                                selection: $cameraVM.selectedFrameRate
                            ) {
                                ForEach(FrameRate.allCases) { rate in
                                    Text("\(rate.rawValue) fps").tag(rate)
                                }
                            }
                        } header: {
                            Text("Video Settings")
                        }
                        
                        Section {
                            Toggle(isOn: $cameraVM.countdownOnOff) {
                                Text("Count Down")
                            }
                            Picker(
                                selection: $cameraVM.selectedCountdown,
                                label: Text("Select Duration")
                            ) {
                                ForEach(1...15, id: \.self) {
                                    Text("\($0) seconds")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 60)
                        } header: {
                            Text("Recording Count Down")
                        }
                        
                        Section {
                            Toggle(isOn: $inLine) {
                                Text("In Line")
                            }
                            Text("When In Line is turned on, the text will be formatted as a single word per line, rather than continuing to flow as it would with the default formatting.")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        } header: {
                            Text("In Line Text")
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
                                                        withAnimation {
                                                            opacity = 1.0
                                                        }
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
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .opacity(opacity) // Apply opacity to entire Form
                }
                .navigationTitle("Settings")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(VideoCameraViewModel())
        .environmentObject(ContentViewModel())
}
