//
//  OnboardingView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/28/25.
//

import SwiftUI

// Main Onboarding View using TabView for paging
struct OnboardingView: View {
    
    var body: some View {
        TabView {
            OnboardingPage1()
            OnboardingPage2()
            PaywallView()
//            OnboardingPage3()
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea(.all)
    }
}

// Page 1: Welcome Screen
struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to Teleprompter DE")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
                .multilineTextAlignment(.center)
            
            Text("Your professional teleprompter app for iPhone and iPad. Deliver speeches, videos, and presentations with ease.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(Color.gray)
            
            Spacer()
        }
        
    }
}

// Page 2: Quick Start - Key
struct OnboardingPage2: View {
    var body: some View {
        VStack {
            
            Text("Quick start guide")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
            
            Text("Here is the quick overview of how to use the app")
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(Color.gray)
            
            Image("app_key")
                .resizable()
                .scaledToFit()
            //.scaleEffect(1.1)
            
            
            
            Spacer()
        }.frame(maxWidth: .infinity)
        .background(.white)
        
        
    }
}


//// Page 3: Get Started
//struct OnboardingPage3: View {
//    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
//    
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 20) {
//                Spacer()
//                
//                Image("logo")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 100, height: 100)
//                    .foregroundColor(.purple)
//                
//                Text("Ready to Start?")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .multilineTextAlignment(.center)
//                    .foregroundStyle(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
//                
//                Text("Dive into Teleprompter DE and deliver your best performance yet.")
//                    .font(.body)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
//                    .foregroundStyle(Color.gray)
//                
//                Button(action: {
//                    
//                    isOnboardingComplete = true
//                }) {
//                    Text("Get Started")
//                        .font(.headline)
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//                .padding(.horizontal)
//                
//                Spacer()
//            }
//            
//            .background(Color.white)
//            
//        }
//    }
//}

// Preview Provider for Xcode Previews
#Preview {
    OnboardingView().environmentObject(PaywallViewModel())
    
}
