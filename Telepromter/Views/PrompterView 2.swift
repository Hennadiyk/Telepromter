//
//  PrompterView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import SwiftUI

struct PrompterView: View {
    @EnvironmentObject var contentVM: ContentViewModel
    //@Binding var readingStyle: Bool
    @AppStorage("readingStyle") var readingStyle: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Highlight bar at the center
//                Text("")
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 1)
//                    .background(.white)
//                    .opacity(0.5)
                //.blur(radius: 2)
                VStack{
                    ScrollView {
                        VStack {
                            if !readingStyle {
                                Text(contentVM.textInput)
                                    .padding(25)
                                    .font(.custom("Arial", size: 20 + contentVM.fontSize/4))
                            } else {
                                ForEach(0..<contentVM.words.count, id: \.self) { index in
                                    Text(contentVM.words[index])
                                        .font(.custom("Arial", size: 28))
                                        .foregroundStyle(contentVM.currentWordIndex == index ? Color.color.theme : Color.color.text)
                                        .id(index)
                                }
                            }
                        }
                        .gesture(DragGesture()
                            .onChanged { value in
                                contentVM.stopScrolling()
                                contentVM.manualOffset -= value.translation.height
                            }
                            .onEnded { _ in
                                contentVM.handleManualScroll(offset: contentVM.manualOffset)
                            }
                                 
                        )
                        .offset(y: -contentVM.scrollOffset)
                        .padding(.vertical, geometry.size.height / 3)
                        .onChange(of: contentVM.isPlaying) {
                            if contentVM.isPlaying && !contentVM.scrollDisabled {
                                contentVM.syncScrollWithWord()
                                contentVM.startScrolling()
                            } else {
                                contentVM.stopScrolling()
                            }
                        }
                        .onChange(of: contentVM.scrollSpeed) {
                            // Update speed dynamically when slider is changed
                            contentVM.updateScrollSpeed()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height / 1.4 - 10)
                    .scrollIndicators(.hidden)
                    //Magnification Gesture for the circle
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }
    }
}
#Preview {
    PrompterView().environmentObject(ContentViewModel())
}
