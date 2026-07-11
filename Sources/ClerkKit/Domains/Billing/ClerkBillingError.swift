//
//  ClerkBillingError.swift
//  Clerk
//

import Foundation

/// Errors that can occur during billing and In-App Purchase operations.
public enum ClerkBillingError: Error, LocalizedError, Equatable, Sendable {
  /// A purchase was attempted without a signed-in user.
  case notSignedIn

  /// No store product matching the request is mapped to the plan.
  ///
  /// When `productId` is `nil`, the plan has no App Store product mapped at all; when it is
  /// non-`nil`, the requested product is not among the plan's mappings. Map the store product
  /// to the plan in the Clerk Dashboard.
  case storeProductNotConfigured(planId: String, productId: String?)

  /// The plan maps multiple store products and no `productId` narrowed them to one.
  ///
  /// The associated `productIds` lists the mapped products. Pass one of them to
  /// ``Billing/purchase(plan:productId:)`` to choose which product to buy.
  case ambiguousStoreProduct(planId: String, productIds: [String])

  /// The mapped store product could not be loaded from the App Store.
  case productNotFound(productId: String)

  /// The user cancelled the purchase.
  case purchaseCancelled

  /// The purchase is pending external action (for example Ask to Buy) and may complete later.
  ///
  /// If it completes, the transaction is delivered through `Transaction.updates` and registered
  /// automatically while transaction observation is active.
  case purchasePending

  /// StoreKit could not verify the transaction's signature.
  case verificationFailed

  /// The user already has an active subscription managed by another payment processor.
  ///
  /// Purchasing another App Store product while the active subscription is also managed by
  /// the App Store is a plan change, not a conflict, so this error only occurs across
  /// processors — for example when the active subscription is managed by `stripe` or
  /// `google`. The associated value identifies the processor that manages the existing
  /// subscription when the API provides it.
  case alreadySubscribed(via: String?)

  public var errorDescription: String? {
    switch self {
    case .notSignedIn:
      "A user must be signed in to complete a purchase."
    case .storeProductNotConfigured(let planId, let productId):
      if let productId {
        "Plan \(planId) has no App Store mapping for product \(productId)."
      } else {
        "Plan \(planId) has no App Store product mapped."
      }
    case .ambiguousStoreProduct(let planId, let productIds):
      "Plan \(planId) maps multiple App Store products (\(productIds.joined(separator: ", "))). Pass a productId to purchase(plan:productId:) to choose one."
    case .productNotFound(let productId):
      "The App Store product \(productId) could not be loaded."
    case .purchaseCancelled:
      "The purchase was cancelled."
    case .purchasePending:
      "The purchase is pending and may complete later."
    case .verificationFailed:
      "The App Store transaction could not be verified."
    case .alreadySubscribed(let via):
      if let via {
        "The user already has an active subscription managed by \(via)."
      } else {
        "The user already has an active subscription managed by another payment processor."
      }
    }
  }
}

extension ClerkBillingError {
  /// Creates an `alreadySubscribed` error from a Clerk API error when the API signals that the
  /// user already has an active subscription through another payment processor.
  init?(apiError: ClerkAPIError) {
    guard apiError.code == "already_subscribed" else {
      return nil
    }

    // The decoder's snake-case conversion also rewrites dictionary keys inside `meta`,
    // so look the value up under both spellings.
    let via = apiError.meta?["already_subscribed_via"] ?? apiError.meta?["alreadySubscribedVia"]
    self = .alreadySubscribed(via: via?.stringValue)
  }
}
