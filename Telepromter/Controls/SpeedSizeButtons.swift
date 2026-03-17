//
//  SpeedSizeButtons.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 7/1/25.
//

import SwiftUI

struct SpeedSizeButtons: View {
    @Environment(ContentViewModel.self) var contentVM
    @AppStorage("textSize") private var textSize: Int = 3
    @AppStorage("speedValue") private var speedValue: Double = 2.5
    @State private var opacity: Double = 1.0
    @State private var speedOpacity: Double = 0.0
    @Binding var fontSpeedBar: Bool

    var body: some View {
        ZStack {
            VStack {
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
            }
        }
        .padding(.bottom, 80)
    }
}

#Preview {
    SpeedSizeButtons(fontSpeedBar: .constant(true))
        .environment(ContentViewModel())
}
