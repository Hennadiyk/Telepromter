//
//  MotionManager.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 11/7/24.
//

import Foundation
import CoreMotion
import SwiftUI
import Observation

@Observable @MainActor
final class MotionManager {
    var x = 0.0
    var y = 0.0

    @ObservationIgnored private let motionManager = CMMotionManager()

    init() {
        motionManager.deviceMotionUpdateInterval = 1 / 24
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let motion = data?.attitude else { return }
            withAnimation(.bouncy(duration: 2)) {
                self?.x = motion.roll
                self?.y = motion.pitch
            }
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
