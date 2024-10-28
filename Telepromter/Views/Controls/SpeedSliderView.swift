//
//  SliderView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/25/24.
//

import SwiftUI

struct SliderView: View {
    @EnvironmentObject var contentVM: ContentViewModel
    @State private var sliderValue: Double = 0
    @State private var opacity: Double = 0.1
    @State private var slideOver: Double = 0
    
    var body: some View {
       
        ZStack{
            HStack{
                Spacer()
                VStack{
                    Capsule()
                        .frame(width: 15, height: 160)
                        .foregroundStyle(Color.color.text)
                        .opacity(opacity)
                    Capsule()
                        .frame(width: 15, height: 40)
                        .offset(y: 120 - sliderValue)
                        .opacity(opacity + 0.3)
                        .offset(y: -168)
                        .overlay{
                            Image(systemName: "textformat.size")
                                .rotationEffect(.degrees(90))
                                .font(.custom("Arial", size: 16))
                                .opacity(opacity)
                                .offset(y: -10)
                        }
                        .gesture(DragGesture()
                            .onChanged { value in
                                withAnimation(.smooth){
                                    sliderValue = min(max(0, 10 - value.translation.height), 120)
                                    opacity = 0.6
                                    slideOver = 5
                                    contentVM.fontSize = sliderValue
                                }
                            }.onEnded { value in
                                withAnimation(.spring(duration: 2)){
                                    opacity = 0.1
                                    slideOver = 0
                                }
                            })
                }
            }.offset(x: UIDevice.isIPad ? -15 - slideOver : -8 - slideOver, y: 160)
        }
    }
}

#Preview {
    SliderView().environmentObject(ContentViewModel())
}
