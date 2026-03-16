//
//  Device.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/10/24.
//

import Foundation
import SwiftUI

extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}


