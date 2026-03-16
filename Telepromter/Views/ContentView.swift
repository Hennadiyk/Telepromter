//
//  test.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 6/30/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var cameraViewModel: VideoCameraViewModel
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
 
    var body: some View {
        ZStack{
            
            if isOnboardingComplete {
                
                TabView(selection: $contentViewModel.selectedTab){
                    Tab("Add Text", systemImage: "character.cursor.ibeam", value: 0) {
                        TextInputView()
                        
                    }.badge(.zero)
                    
                    Tab("Teleprompter", systemImage: "text.aligncenter", value: 1) {
                        ControlsView()
                    }
                    
                    Tab("Account", systemImage: "person.crop.circle", value: 2, role: UIDevice.isIPad ? .none : .search) {
                        AccountDetailsView()
                        
                    }
                    
                }
            } else {
                
                OnboardingView()
                
            }
        }
    }
}
#Preview {
    ContentView()
        .environmentObject(VideoCameraViewModel())
        .environmentObject(ContentViewModel())
        .environmentObject(PaywallViewModel())
}
