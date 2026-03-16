//
//  Haptics.swift
//  Hennadiy
//
//  Created by Hennadiy Kvasov on 8/9/23.
//  Updated for safe, lazy CoreHaptics usage.
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - Public helpers you already call

func simpleSuccess() {
    Haptics.shared.success()
}

func complexSuccess() {
    Haptics.shared.complex()
}

// MARK: - Haptics

final class Haptics {
    
    static let shared = Haptics()
    
#if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
#endif
    private var supportsHaptics = false
    private var prepared = false
    
    private init() {
        // Lazy; we won’t prepare here to avoid doing CoreHaptics work at launch on unsupported targets.
    }
    
    // MARK: Public API
    
    func success() {
#if os(iOS)
        prepareIfNeeded()
        if supportsHaptics, let player = makeTransientPlayer(intensity: 0.7, sharpness: 0.8) {
            do { try player.start(atTime: 0) } catch { fallbackSuccess() }
        } else {
            fallbackSuccess()
        }
#endif
    }
    
    func complex() {
#if os(iOS)
        prepareIfNeeded()
        if supportsHaptics, let player = makeComplexPlayer() {
            do { try player.start(atTime: 0) } catch { fallbackSuccess() }
        } else {
            fallbackSuccess()
        }
#endif
    }
    
    // MARK: Setup
    
    private func prepareIfNeeded() {
        guard !prepared else { return }
        prepared = true
        
#if os(iOS)
        
        // Don’t attempt CoreHaptics on Simulator / Catalyst / when the hardware doesn’t support it.
#if targetEnvironment(simulator)
        supportsHaptics = false
        return
#endif
        
#if canImport(CoreHaptics)
        let caps = CHHapticEngine.capabilitiesForHardware()
        supportsHaptics = caps.supportsHaptics
        guard supportsHaptics else { return }
        
        do {
            // Lazily create/start the engine
            engine = try CHHapticEngine()
            configureHandlers()
            try engine?.start()
        } catch {
            // If engine fails, disable CoreHaptics for this session; we’ll fall back cleanly.
            supportsHaptics = false
            engine = nil
        }
#else
        supportsHaptics = false
#endif
        
#endif
    }
    
#if canImport(CoreHaptics)
    private func configureHandlers() {
        engine?.stoppedHandler = { [weak self] reason in
            // Will be restarted lazily on next use.
            // .stopped due to .audioSessionInterrupt / .applicationSuspended can occur.
            self?.engine = nil
        }
        
        engine?.resetHandler = { [weak self] in
            // The engine was restarted by the system; recreate on next use.
            self?.engine = nil
        }
    }
#endif
    
    // MARK: Players
    
#if canImport(CoreHaptics)
    private func ensureEngineStarted() -> Bool {
        guard supportsHaptics else { return false }
        if engine == nil {
            do {
                engine = try CHHapticEngine()
                configureHandlers()
                try engine?.start()
            } catch {
                supportsHaptics = false
                engine = nil
                return false
            }
        }
        return true
    }
    
    private func makeTransientPlayer(intensity: Float, sharpness: Float) -> CHHapticAdvancedPatternPlayer? {
        guard ensureEngineStarted() else { return nil }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            return try engine?.makeAdvancedPlayer(with: pattern)
        } catch {
            return nil
        }
    }
    
    private func makeComplexPlayer() -> CHHapticAdvancedPatternPlayer? {
        guard ensureEngineStarted() else { return nil }
        
        // Descending pattern for intensity/sharpness; keep it short and lightweight
        var events: [CHHapticEvent] = []
        let steps: [Double] = stride(from: 0.0, through: 0.3, by: 0.1).map { $0 }
        for (i, t) in steps.enumerated() {
            let inten = Float(0.2 - Double(i) * 0.15)
            let sharp = Float(0.5 - Double(i) * 0.2)
            let params = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, inten)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, sharp))
            ]
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: t))
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            return try engine?.makeAdvancedPlayer(with: pattern)
        } catch {
            return nil
        }
    }
#endif
    
    // MARK: Fallbacks
    
#if os(iOS)
    private func fallbackSuccess() {
        // Always available on iOS (even Simulator), and does not spam CoreHaptics.
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
#endif
}
