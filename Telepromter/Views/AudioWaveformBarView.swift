//
//  AudioWaveformBarView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/16/25.
//

import SwiftUI

struct AudioWaveformBarView: View {
    let levels: [Float]
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    let level = levels[index]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(gradient(for: level))
                        .frame(width: geo.size.width / CGFloat(levels.count), height: CGFloat(level) * geo.size.height)
                }
            }
        }
    }
    
    private func gradient(for level: Float) -> LinearGradient {
        if level > 0.8 {
            return LinearGradient(colors: [.red, .gray], startPoint: .bottom, endPoint: .top)
        } else if level > 0.5 {
            return LinearGradient(colors: [.gray, .gray], startPoint: .bottom, endPoint: .top)
        } else {
            return LinearGradient(colors: [.gray, .gray], startPoint: .bottom, endPoint: .top)
        }
    }
}
