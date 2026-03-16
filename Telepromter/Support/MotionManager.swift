//
//  MotionManager.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 11/7/24.
//

import Foundation
import CoreMotion
import SwiftUI
//Motion Manager for Header

class MotionManager: ObservableObject {
    
    private let motionManager = CMMotionManager()
    @Published var x = 0.0
    @Published var y = 0.0
    
    init() {
        withAnimation(.bouncy(duration: 2)){
            motionManager.deviceMotionUpdateInterval = 1/24
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                guard let motion = data?.attitude else { return }
                
                self?.x = motion.roll
                self?.y = motion.pitch
            }
        }
    }
    
}
