//
//  ReviewView.swift
//  Teleprompter DE
//

import SwiftUI
import StoreKit

struct ReviewView: View {
    @Binding var isPresented: Bool

    @AppStorage("hasRatedOrReviewed") var hasRatedOrReviewed: Bool = false
    @AppStorage("reviewLastDismissedDate") private var reviewLastDismissedDate: Double = 0

    private let appStoreID = "6748670093"

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { maybeLater() }

            VStack(spacing: 20) {
                Image(systemName: "text.aligncenter")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.color.gradientHigh)

                VStack(spacing: 8) {
                    Text("Enjoying Teleprompter DE?")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    Text("Rate us or write a review to help\nothers discover the app. Thank you!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button(action: submitRating) {
                        Text("Rate the App")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.color.gradientHigh)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: writeReview) {
                        Text("Write a Review")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.color.gradientHigh.opacity(0.15))
                            .foregroundStyle(Color.color.gradientHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: maybeLater) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 28)
        }
    }

    private func submitRating() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 16, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
        hasRatedOrReviewed = true
        isPresented = false
    }

    private func writeReview() {
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
        hasRatedOrReviewed = true
        isPresented = false
    }

    private func maybeLater() {
        reviewLastDismissedDate = Date().timeIntervalSince1970
        isPresented = false
    }
}

#Preview {
    ReviewView(isPresented: .constant(true))
}
