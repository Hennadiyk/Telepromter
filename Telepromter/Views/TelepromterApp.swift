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
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct TelepromterApp: App {
    
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var videoViewModel = VideoCameraViewModel()
    @StateObject private var paywallViewModel = PaywallViewModel()
    var updateListenerTask : Task<Void, Error>? = nil
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(contentViewModel).environmentObject(videoViewModel).environmentObject(paywallViewModel)
        }
        
        
        
    }
}
