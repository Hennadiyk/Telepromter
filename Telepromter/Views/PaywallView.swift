//
//  PaywallView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/18/25.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var paywallViewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.gray, .clear]), startPoint: .top, endPoint: .bottom)
                    .opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    ZStack {
                        
                        SubscriptionStoreView(productIDs: paywallViewModel.productIDs, marketingContent: {
                            
                            HeaderImageView(geo: geo)
                            
                        })
                        .storeButton(.visible, for: .restorePurchases)
                        .subscriptionStoreControlStyle(.compactPicker)
                        .onInAppPurchaseCompletion { product, result in
                            // Handle purchase result (e.g., check for success)
                            if case .success = result {
                                dismiss() // Dismiss the view on successful purchase
                                isOnboardingComplete = true
                                await paywallViewModel.updateCustomerProductStatus()
                            } else {
                                print("Something went wrong")
                            }
                        }
                    }
                    .ignoresSafeArea(.all)
                }
            }
            
        }
    }
}

struct HeaderImageView: View {
    let geo: GeometryProxy
    var body: some View {
        
        ZStack {
            Spacer()
            VStack{
                //Spacer()
                VStack{
                    Text("Teleprompter DE")
                        .font(.largeTitle)
                        .bold()
                    Text("Premium")
                        .font(.headline)
                }
                .frame(height: 150)
                .foregroundStyle(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                //Free Premium
                HStack(alignment: .center) {
                    ZStack {
                        // Free capsule
                        RoundedRectangle(cornerRadius: 50)
                            .frame(width: 140, height: 20) // Fixed width
                            .foregroundStyle(.gray)
                            .overlay(
                                Text("Free")
                                    .foregroundStyle(Color.white) // Adjust color as needed
                                    .font(.caption)
                                    .bold()
                                    .offset(x: -40) // Adjusted offset for consistent text placement
                            )
                        
                        // Premium capsule
                        RoundedRectangle(cornerRadius: 50)
                            .foregroundStyle(.blue)
                            .frame(width: 100, height: 20) // Fixed width
                            .offset(x: 30) // Adjusted offset for consistent positioning
                            .overlay(
                                Text("Premium")
                                    .foregroundStyle(Color.white) // Adjust color as needed
                                    .font(.caption)
                                    .bold()
                                    .offset(x: 30) // Adjusted offset for consistent text placement
                            )
                    }
                }
                
                //Features
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.gray)
                        Text("Teleprompter with two scroll options")
                    }  .padding(.vertical, 1)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.gray)
                        Text("Import PDFs and Text files")
                    }  .padding(.vertical, 1)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Record and save video")
                    }  .padding(.vertical, 1)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Auto-connect bluetooth microphones")
                    }  .padding(.vertical, 1)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Custom background colors")
                    }  .padding(.vertical, 1)
                }
                .padding(.top, 40)
                .font(.system(size: 16))
                
            }
        }
       
        
    }
}
#Preview {
    PaywallView().environmentObject(PaywallViewModel())
}
