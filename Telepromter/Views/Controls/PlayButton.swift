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
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: 42, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
        return path
    }
}

struct ResizeBar: View {
    @EnvironmentObject private var contentVM: ContentViewModel
    @State private var lineAngle = 1.0
    
    var body: some View {
        ZStack {
            Arc(startAngle: .degrees(80),
                endAngle: .degrees(-1),
                clockwise: false)
            .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            .opacity(1)
            Arc(startAngle: .degrees(80),
                endAngle: .degrees(80 - (80 * min(contentVM.progress, 1))),
                clockwise: false)
            .stroke(.green, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            
            .onAppear() {
                withAnimation(.bouncy(duration: 2)) {
                    lineAngle = 80
                }
            }
        }
        .frame(width: 100, height: 100)
        
    }
}

#Preview {
    ResizeBar().environmentObject(ContentViewModel())
}
