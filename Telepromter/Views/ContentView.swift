//
//  test.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/30/25.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        NavigationStack {
               
            TabView {
                Tab("Add Text", systemImage: "character.cursor.ibeam") {
                    TextInputView()
                }
                Tab("Video", systemImage: "video") {
                       
                    ControlsView()
                }
                Tab("Settings", systemImage: "gear", role: .search) {
                        
                    SettingsView()
                        
                }
            }
        }
    }
}
#Preview {
    ContentView()
        .environmentObject(VideoCameraViewModel())
        .environmentObject(ContentViewModel())
}
