//
//  Helper.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/12/25.
//

import Foundation

func timeString(from time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
