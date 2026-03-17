//
//  TelepromterApp.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct TelepromterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var contentViewModel = ContentViewModel()
    @State private var videoViewModel = VideoCameraViewModel()
    @State private var paywallViewModel = PaywallViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(contentViewModel)
                .environment(videoViewModel)
                .environment(paywallViewModel)
        }
    }
}
