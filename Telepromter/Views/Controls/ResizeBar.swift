//
//  ResizeBar.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 11/3/24.
//

import SwiftUI

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool
    
   
    
    func path(in rect: CGRect) -> Path {
        //let rotationAdjustment = Angle.degrees(90)
        //let modifiedStart = startAngle - rotationAdjustment
        //let modifiedEnd = endAngle - rotationAdjustment
        
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: 42, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
        return path
    }
}

struct ResizeBar: View {
    
    @EnvironmentObject private var contentVM: ContentViewModel
    @State private var lineAngle = 1.0
    
    
    var body: some View {
        ZStack{
            Arc(startAngle: .degrees(lineAngle), endAngle: .degrees(-1), clockwise: false)
                .stroke(Color.color.background, style: StrokeStyle(lineWidth:6, lineCap: .round, lineJoin: .round))
                .opacity(0.8)
            Arc(startAngle: .degrees(lineAngle), endAngle: .degrees(80 - contentVM.progress), clockwise: false)
                .stroke(.green, style: StrokeStyle(lineWidth:6, lineCap: .round, lineJoin: .round))
                .opacity(1)
            //.animation(.easeInOut(duration: 2), value: lineAngle)
            //           .border(.blue)
                .onAppear(){
                    withAnimation(.bouncy(duration: 2)){
                        lineAngle = 80
                    }
                }
            
        }
         .frame(width:100, height: 100)
    }
}

#Preview {
    ResizeBar().environmentObject(ContentViewModel())
}
