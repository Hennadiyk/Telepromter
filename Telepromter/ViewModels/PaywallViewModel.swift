//
//  PaywallViewModel.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/21/25.
//

import Foundation
import StoreKit
import Observation

typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

@Observable @MainActor
final class PaywallViewModel {
    private(set) var subscriptions: [Product] = []
    private(set) var purchasedSubscriptions: [Product] = []
    private(set) var subscriptionGroupStatus: RenewalState?
    var isPresented = false

    let productIDs: [String] = ["TDE_2.99_Monthly", "TDE_34.99_Annual"]

    @ObservationIgnored private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updateCustomerProductStatus()
                    await transaction?.finish()
                } catch {
                    print("transaction failed verification")
                }
            }
        }
    }

    func fetchProducts() async {
        do {
            subscriptions = try await Product.products(for: productIDs)
        } catch {
            print("Failed product request from app store server: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
                await transaction.finish()
            } catch {
                print("failed updating products")
            }
        }
    }

    func shouldShowPaywall() -> Bool {
        if !purchasedSubscriptions.isEmpty { return false }
        if let status = subscriptionGroupStatus {
            switch status {
            case .expired, .revoked: return true
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod: return false
            default: return true
            }
        }
        return true
    }
}

public enum StoreError: Error {
    case failedVerification
}
