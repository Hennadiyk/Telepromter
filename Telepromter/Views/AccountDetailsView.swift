//  AccountView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/17/25.
//

import SwiftUI
import StoreKit

struct AccountDetailsView: View {
    @Environment(PaywallViewModel.self) private var paywallViewModel

    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView()
                    .opacity(0.4)
                VStack(alignment: .leading, spacing: 0) {
                    List {
                        Section {
                            HStack {
                                Image("logo")
                                    .resizable()
                                    .frame(width: 85, height: 85)

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text(subscriptionStatus)
                                        .font(.largeTitle)
                                        .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .bold()
                                    Text(subscriptionDescription)
                                        .font(.body)
                                        .foregroundColor(Color.color.gradientLow)

                                    if !paywallViewModel.purchasedSubscriptions.isEmpty {
                                        Button("Manage Subscription") {
                                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                                Task {
                                                    do {
                                                        try await AppStore.showManageSubscriptions(in: windowScene)
                                                    } catch {
                                                        print("Failed to show manage subscriptions: \(error)")
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
                                    } else {
                                        Text("No active subscription.")
                                            .foregroundColor(.gray)

                                        Button("Subscribe Now") {
                                            paywallViewModel.isPresented = true
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
                                    }
                                }
                            }
                        }

                        Section {
                            NavigationLink(destination: SettingsView()) {
                                Text("Settings")
                                    .padding(.vertical, 10)
                            }
                        }

                        Section {
                            NavigationLink(destination: FeatureRequestView()) {
                                Text("Feature Request")
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                    .listStyle(DefaultListStyle())
                    .refreshable {
                        await paywallViewModel.updateCustomerProductStatus()
                    }

                    Spacer()
                    termsofUseURL
                    eulaPolicyURL

                    Text("Teleprompter DE v\(appVersionTag)")
                        .font(.footnote)
                        .bold()
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                }
                .navigationTitle("My Account")
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial.opacity(0.5))
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: Bindable(paywallViewModel).isPresented) {
            PaywallView()
        }
    }
}

#Preview {
    AccountDetailsView()
        .environment(VideoCameraViewModel())
        .environment(PaywallViewModel())
}

extension AccountDetailsView {
    var subscriptionStatus: String {
        if !paywallViewModel.purchasedSubscriptions.isEmpty {
            return "\(paywallViewModel.purchasedSubscriptions.first!.displayName)"
        } else if let status = paywallViewModel.subscriptionGroupStatus {
            switch status {
            case .expired: return "Expired"
            case .revoked: return "Revoked"
            default: return "No Active Subscription"
            }
        }
        return "No Active Subscription"
    }

    var subscriptionDescription: String {
        paywallViewModel.purchasedSubscriptions.first?.description ?? ""
    }

    var appVersionTag: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var termsofUseURL: some View {
        Button("Privacy Policy") {
            if let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/teleprompterde-a3363.firebasestorage.app/o/privacy-policy.html?alt=media&token=cef92393-c810-487d-a3e9-5aa9705ba36c") {
                UIApplication.shared.open(url)
            }
        }
        .font(.caption)
        .foregroundColor(.gray)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 5)
    }

    var eulaPolicyURL: some View {
        Button("Terms of Use (EULA)") {
            if let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/teleprompterde-a3363.firebasestorage.app/o/eula.html?alt=media&token=2de9e5f4-0ed9-4718-bcf4-44b7a8b98ad2") {
                UIApplication.shared.open(url)
            }
        }
        .font(.caption)
        .foregroundColor(.gray)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 5)
    }
}
