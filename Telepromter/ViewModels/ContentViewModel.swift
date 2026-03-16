//
//  ContentViewModel.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/10/24.
//

import Combine
import SwiftUI

class ContentViewModel: ObservableObject {
    @Published var textInput: String = "" {
        didSet { words = textInput.components(separatedBy: " ").filter { !$0.isEmpty } }
    }
    @Published var words: [String] = []
    @Published var isPlaying: Bool = false
    
    @AppStorage("scrollSpeed") var scrollSpeed: Double = 20.0
    @AppStorage("fontSize") var fontSize: Double = 0.0
    
    @Published var textInputWindowHeight: CGFloat = 300.0
    @Published var progress: Double = 0.0
    @Published var yOffset: CGFloat = 0.0
    @Published var textContentHeight: CGFloat = 0
    
    @Published var initialDragOffset: CGFloat = 0.0
    @Published var videoOn: Bool = false
    @Published var selectedTab: Int = 1
    
    init() {
        words = textInput.components(separatedBy: " ").filter { !$0.isEmpty }
    }
    
    func updateProgress() {
        let visibleH = textInputWindowHeight
        let totalH = textContentHeight
        let startOffset: CGFloat = visibleH // Bottom
        let endOffset: CGFloat = -totalH    // Top
        let totalDistance = startOffset - endOffset
        let scrolled = startOffset - yOffset
        progress = totalDistance > 0 ? min(max(scrolled / totalDistance, 0.0), 1.0) : 0
    }
}

