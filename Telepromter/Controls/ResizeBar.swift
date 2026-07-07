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
    @Environment(VideoCameraViewModel.self) private var cameraViewModel
    @Environment(ContentViewModel.self) private var contentVM
    @Binding var progress: Double
    @State private var lineAngle = 1.0

    var body: some View {
        ZStack {
            Arc(startAngle: .degrees(80),
                endAngle: .degrees(-1),
                clockwise: false)
            .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))

            // Progress arc
            Arc(startAngle: .degrees(80),
                endAngle: .degrees(80 - (80 * min(progress, 1))),
                clockwise: false)
            .stroke(Color.color.gradientLow, style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
            .onAppear {
                withAnimation(.bouncy(duration: 2)) { lineAngle = 80 }
            }
            
            Button {
                contentVM.scrollToTopToken = UUID()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.color.gradientLow)
                    .padding(8)
            }
            .offset(x: 42, y: -40)
        }
        .frame(width: 105, height: 105)
        
    }
}

#Preview {
    ResizeBar(progress: .constant(0.5))
        .environment(VideoCameraViewModel())
        .environment(ContentViewModel())
}
