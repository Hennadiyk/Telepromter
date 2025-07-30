//
//  AccountView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/17/25.
//

import SwiftUI

struct MyAccountView: View {
    // Placeholder for user name; in a real app, this would come from a view model or user data
    let userName: String = "John Doe"
    
    // App name and version
    let appName: String = "Teleprompter DE"
    let appVersion: String = {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        } else {
            return "1.0" // Fallback version
        }
    }()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                List {
                    // Top: Tapable name linking to profile details
                    NavigationLink(destination: ProfileDetailsView()) {
                        Text(userName)
                            .font(.title2)
                            .bold()
                            .padding(.vertical, 10)
                    }
                    
                    // Manage subscription link
                    NavigationLink(destination: SubscriptionDetailsView()) {
                        Text("Manage My Subscription")
                            .padding(.vertical, 10)
                    }
                    
                    // Settings link
                    NavigationLink(destination: SettingsView()) {
                        Text("Settings")
                            .padding(.vertical, 10)
                    }
                }
                .listStyle(PlainListStyle())
                
                Spacer()
                
                // Bottom: App name and version
                Text("\(appName) v\(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
            .navigationTitle("My Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MyAccountView().environmentObject(VideoCameraViewModel())
}
