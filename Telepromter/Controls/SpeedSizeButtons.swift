//
//  SpeedSizeButtons.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 7/1/25.
//

import SwiftUI

struct SpeedSizeButtons: View {
    @EnvironmentObject var contentVM: ContentViewModel
    @AppStorage("textSize") private var textSize: Int = 3 // Default to 3
    @AppStorage("speedValue") private var speedValue: Double = 2.5 // Default to 2 (middle of 1–5)
    @State private var opacity: Double = 1.0
    @State private var speedOpacity: Double = 0.0
    @Binding var fontSpeedBar: Bool
    
    var body: some View {
        ZStack {
            VStack{
                Spacer()
                HStack{
                    HStack {
                        HStack {
                            // Plus button to increase text size
                            Button(
                                action: {
                                    withAnimation(.smooth) {
                                        simpleSuccess()
                                        textSize = min(
                                            textSize + 1,
                                            10
                                        ) // Max 8
                                        contentVM.fontSize = Double(
                                            textSize * 10
                                        ) // Map 1–5 to 10–50 for fontSize
                                        opacity = 0.3
                                    }
                                    DispatchQueue.main
                                        .asyncAfter(deadline: .now() + 2) {
                                            withAnimation(.smooth) {
                                                opacity = 0.0
                                            }
                                        }
                                }) {
                                    Text("+")
                                        .font(.system(size: 25))
                                        .bold()
                                        .foregroundStyle(Color.color.text)
                                        .frame(width: 30, height: 30)
                                    
                                }
                                .disabled(textSize >= 10)
                            
                            // Display current text size (1–5)
                            Text("\(textSize)")
                                .font(.system(size: 35))
                                .frame(width: 54)
                                .bold()
                                .opacity(1)
                                .foregroundStyle(
                                    textSize >= 10 ? .orange : Color.color.text
                                )// Disable when at max
                            
                            // Minus button to decrease text size
                            Button(
                                action: {
                                    withAnimation(.smooth) {
                                        simpleSuccess()
                                        textSize = max(textSize - 1, 1) // Min 1
                                        contentVM.fontSize = Double(
                                            textSize * 10
                                        ) // Map 1–5 to 10–50 for fontSize
                                        opacity = 1
                                    }
                                    DispatchQueue.main
                                        .asyncAfter(deadline: .now() + 2) {
                                            withAnimation(.smooth) {
                                                opacity = 0.0
                                            }
                                        }
                                }) {
                                    Text("-")
                                        .font(.system(size: 40))
                                        .bold()
                                        .foregroundStyle(Color.color.text)
                                        .frame(width: 30, height: 30)
                                    
                                }
                                .disabled(textSize <= 1) // Disable when at min
                            
                            Spacer()
                            
                            // Icon above buttons
                            Image(systemName: "textformat.size")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)
                                .opacity(1)
                                .onTapGesture {
                                    withAnimation(.bouncy){
                                        fontSpeedBar.toggle()
                                    }
                                }
                        }
                        
                        Divider().onTapGesture {
                            withAnimation(.bouncy){
                                fontSpeedBar.toggle()
                            }
                        }
                        
                        HStack{
                            
                            // Icon above buttons
                            Image(systemName: "figure.run")
                                .font(.custom("Arial", size: 16))
                                .foregroundStyle(Color.color.text)
                                .opacity(1)
                                .onTapGesture {
                                    withAnimation(.bouncy){
                                        fontSpeedBar.toggle()
                                    }
                                }
                            
                            // Plus button to increase speed
                            Button(
                                action: {
                                    simpleSuccess()
                                    withAnimation(.smooth) {
                                        speedValue = max(
                                            speedValue - 0.5,
                                            0.5
                                        ) // Min 1
                                        contentVM.scrollSpeed = Double(
                                            speedValue * 5
                                        ) // Map 1–5 to 10–50
                                        speedOpacity = 0.8
                                    }
                                    DispatchQueue.main
                                        .asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.smooth) {
                                                speedOpacity = 0.3
                                            }
                                        }
                                }) {
                                    Text("-")
                                        .font(.system(size: 40))
                                        .bold()
                                        .foregroundStyle(Color.color.text)
                                        .frame(width: 30, height: 30)
                                }
                            
                            
                            // Display current speed value (1–5)
                            Text(String(format: "%.1f", speedValue))
                                .font(.system(size: 35))
                                .frame(width: 54)
                                .bold()
                                .opacity(1)
                                .foregroundStyle(
                                    speedValue >= 6 ? .orange : Color.color.text
                                )// Disable when at max
                            
                            
                            // Minus button to decrease speed
                            Button(
                                action: {
                                    withAnimation(.smooth) {
                                        simpleSuccess()
                                        speedValue = min(
                                            speedValue + 0.5,
                                            6
                                        ) // Max 6
                                        contentVM.scrollSpeed = Double(
                                            speedValue * 5
                                        ) // Map 1–5 to 10–50
                                        speedOpacity = 0.8
                                    }
                                    DispatchQueue.main
                                        .asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.smooth) {
                                                speedOpacity = 0.3
                                            }
                                        }
                                }) {
                                    Text("+")
                                        .font(.system(size: 25))
                                        .bold()
                                        .foregroundStyle(Color.color.text)
                                        .frame(width: 30, height: 30)
                                    
                                }
                                .padding(.vertical, 4)
                                .disabled(
                                    speedValue >= 6
                                ) // Disable when at max
                            
                        }
                        
                    }
                    .frame(width: fontSpeedBar ? 350 : 48, height: 25)
                    .padding(12)
                    .applyIfAvailableGlassClear()
                    .cornerRadius(30)
                    
                    
                    Spacer()
                }
            }
            
        }.padding(.bottom, 85)
        
    }
}

#Preview {
    SpeedSizeButtons(fontSpeedBar: Binding.constant(true))
        .environmentObject(ContentViewModel())
}
