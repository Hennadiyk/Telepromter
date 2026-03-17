//
//  PlayButton.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 11/3/24.
//

import SwiftUI

struct PlayArc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: 42, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
        return path
    }
}

struct PlayButton: View {
    @Environment(ContentViewModel.self) private var contentVM
    @State private var lineAngle = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .overlay {
                    Text(contentVM.isPlaying ? "PAUSE" : "PLAY")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 80, height: 15)
                .foregroundStyle(.blue)
        }
        .frame(width: 100, height: 100)
    }
}

#Preview {
    PlayButton().environment(ContentViewModel())
}
