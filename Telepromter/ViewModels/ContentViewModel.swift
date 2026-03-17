//
//  ContentViewModel.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/10/24.
//

import SwiftUI
import Observation

@Observable @MainActor
final class ContentViewModel {
    var textInput: String = "" {
        didSet { words = textInput.components(separatedBy: " ").filter { !$0.isEmpty } }
    }
    var words: [String] = []
    var isPlaying: Bool = false

    // Observable backing vars — changes here trigger view updates
    var scrollSpeed: Double = 20.0 {
        didSet { storedScrollSpeed = scrollSpeed }
    }
    var fontSize: Double = 0.0 {
        didSet { storedFontSize = fontSize }
    }
    // AppStorage for persistence only (prefixed to avoid clash with @Observable synthesized names)
    @ObservationIgnored @AppStorage("scrollSpeed") private var storedScrollSpeed: Double = 20.0
    @ObservationIgnored @AppStorage("fontSize") private var storedFontSize: Double = 0.0

    var textInputWindowHeight: CGFloat = 300.0
    var progress: Double = 0.0
    var yOffset: CGFloat = 0.0
    var textContentHeight: CGFloat = 0

    var initialDragOffset: CGFloat = 0.0
    var videoOn: Bool = false
    var selectedTab: Int = 1

    init() {
        words = textInput.components(separatedBy: " ").filter { !$0.isEmpty }
        // Load persisted values into observable backing vars
        scrollSpeed = storedScrollSpeed
        fontSize = storedFontSize
    }

    func updateProgress() {
        let visibleH = textInputWindowHeight
        let totalH = textContentHeight
        let startOffset: CGFloat = visibleH
        let endOffset: CGFloat = -totalH
        let totalDistance = startOffset - endOffset
        let scrolled = startOffset - yOffset
        progress = totalDistance > 0 ? min(max(scrolled / totalDistance, 0.0), 1.0) : 0
    }
}
