//
//  OnboardingView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/28/25.
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        TabView {
            OnboardingPage1()
            OnboardingPage2()
            PaywallView()
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea(.all)
    }
}

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
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.white)
    }
}

#Preview {
    OnboardingView().environment(PaywallViewModel())
}
