//
//  PaywallView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/18/25.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PaywallViewModel.self) private var paywallViewModel
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
                        .onInAppPurchaseCompletion { _, result in
                            if case .success = result {
                                dismiss()
                                isOnboardingComplete = true
                                await paywallViewModel.updateCustomerProductStatus()
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
            VStack {
                VStack {
                    Text("Teleprompter DE")
                        .font(.largeTitle)
                        .bold()
                    Text("Premium")
                        .font(.headline)
                }
                .frame(height: 150)
                .foregroundStyle(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .topLeading, endPoint: .bottomTrailing))

                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 50)
                            .frame(width: 140, height: 20)
                            .foregroundStyle(.gray)
                            .overlay(
                                Text("Free")
                                    .foregroundStyle(Color.white)
                                    .font(.caption)
                                    .bold()
                                    .offset(x: -40)
                            )
                        RoundedRectangle(cornerRadius: 50)
                            .foregroundStyle(.blue)
                            .frame(width: 100, height: 20)
                            .offset(x: 30)
                            .overlay(
                                Text("Premium")
                                    .foregroundStyle(Color.white)
                                    .font(.caption)
                                    .bold()
                                    .offset(x: 30)
                            )
                    }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.gray)
                        Text("Teleprompter with two scroll options")
                    }.padding(.vertical, 1)
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.gray)
                        Text("Import PDFs and Text files")
                    }.padding(.vertical, 1)
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        Text("Record and save video")
                    }.padding(.vertical, 1)
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        Text("Auto-connect bluetooth microphones")
                    }.padding(.vertical, 1)
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        Text("Custom background colors")
                    }.padding(.vertical, 1)
                }
                .padding(.top, 40)
                .font(.system(size: 16))
            }
        }
    }
}

#Preview {
    PaywallView().environment(PaywallViewModel())
}
