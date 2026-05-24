//
//  LevelIndicatorView.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 5/24/26.
//

import SwiftUI
import CoreMotion

@Observable @MainActor
private final class LevelMotion {
    var roll: Double = 0

    @ObservationIgnored private let cm = CMMotionManager()

    init() {
        guard cm.isDeviceMotionAvailable else { return }
        cm.deviceMotionUpdateInterval = 1.0 / 60
        cm.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let attitude = data?.attitude else { return }
            Task { @MainActor [weak self] in
                self?.roll = attitude.roll
            }
        }
    }

    deinit { cm.stopDeviceMotionUpdates() }
}

struct LevelIndicatorView: View {
    @State private var motion = LevelMotion()
    @State private var opacity: Double = 1
    @State private var fadeTask: Task<Void, Never>? = nil

    private var isLevel: Bool { abs(motion.roll) < 0.017 } // ~1 degree
    private var color: Color { isLevel ? .yellow : .white }

    var body: some View {
        ZStack {
            // Fixed center tick
            Capsule()
                .fill(color)
                .frame(width: 18, height: 2)
                .shadow(color: .black.opacity(0.4), radius: 1.5)

            // Horizon-aligned rotating line
            Capsule()
                .fill(color)
                .frame(width: 42, height: 2)
                .rotationEffect(.radians(-motion.roll))
                .shadow(color: .black.opacity(0.4), radius: 1.5)
        }
        .opacity(opacity)
        .animation(.linear(duration: 0.05), value: motion.roll)
        .onAppear { scheduleFade() }
        .onChange(of: motion.roll) { oldRoll, newRoll in
            guard abs(newRoll - oldRoll) > 0.005 else { return }
            fadeTask?.cancel()
            withAnimation(.easeIn(duration: 0.15)) { opacity = 1 }
            scheduleFade()
        }
    }

    private func scheduleFade() {
        fadeTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.8)) { opacity = 0 }
        }
    }
}
