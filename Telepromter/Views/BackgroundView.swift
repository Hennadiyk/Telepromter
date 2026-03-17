//
//  BackgroundView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/19/24.
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var motion = MotionManager()
    @AppStorage("themeColor") var themeColor: themeSwitching = .teal

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GeometryReader { proxy in
                    let size = proxy.size

                    Circle()
                        .fill(themeColor.colorTop)
                        .padding(50)
                        .blur(radius: 120)
                        .frame(width: size.width, height: size.height / 2 + 50)
                        .offset(x: -size.width / 3, y: -size.height / 2.8)
                        .offset(x: motion.x * 120, y: motion.y * 120)
                    Circle()
                        .fill(themeColor.colorBottom)
                        .padding(50)
                        .blur(radius: 150)
                        .offset(x: size.width / 3, y: size.height / 1.3)
                        .offset(x: motion.x * 120, y: motion.y * 120)
                }
                RoundedRectangle(cornerRadius: 30)
                    .fill(colorScheme == .light ? .white : .white.opacity(0.1))
                    .blur(radius: 8)
                    .opacity(0.5)
                    .ignoresSafeArea(.all)
                    .overlay {
                        Image("noise")
                            .opacity(0.1)
                    }
            }
        }
    }
}

#Preview {
    BackgroundView()
}
