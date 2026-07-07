//
//  TelepromterApp.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import SwiftUI
import FirebaseCore
import TipKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        if #available(iOS 17, *) {
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
        return true
    }
}

@main
struct TelepromterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var contentViewModel = ContentViewModel()
    @State private var videoViewModel = VideoCameraViewModel()
    @State private var paywallViewModel = PaywallViewModel()
    @State private var voiceScrollViewModel = VoiceScrollViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(contentViewModel)
                .environment(videoViewModel)
                .environment(paywallViewModel)
                .environment(voiceScrollViewModel)
        }
    }
}
