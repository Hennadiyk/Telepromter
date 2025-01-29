//
//  TelepromterApp.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import SwiftUI

@main
struct TelepromterApp: App {
    
    var contentViewModel = ContentViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(contentViewModel)
        }
    }
}
