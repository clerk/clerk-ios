//
//  BillingPlan.swift
//  Clerk
//

import Foundation

/// The `BillingPlan` object describes a subscription plan from the instance's unified billing catalog.
///
/// A single plan can be purchasable on the web (via Clerk's hosted checkout) and/or in the app
/// (via App Store / Google Play In-App Purchase). The ``storeProducts`` mapping links the plan
/// to the store product identifiers configured in the Clerk Dashboard.
public struct BillingPlan: Codable, Equatable, Sendable, Identifiable {
  /// The unique identifier for the plan.
  public var id: String

  /// The display name of the plan.
  public var name: String

  /// The URL-friendly identifier of the plan.
  public var slug: String

  /// The description of the plan.
  public var description: String?

  /// The monthly fee for the plan.
  public var fee: BillingMoneyAmount?

  /// The total annual fee for the plan.
  public var annualFee: BillingMoneyAmount?

  /// The equivalent monthly fee when the plan is billed annually.
  public var annualMonthlyFee: BillingMoneyAmount?

  /// Whether this is the instance's default plan.
  public var isDefault: Bool?

  /// Whether the plan renews on a recurring basis.
  public var isRecurring: Bool?

  /// Whether the plan has a base fee.
  public var hasBaseFee: Bool?

  /// The payer type the plan is offered to (for example `user` or `org`).
  public var forPayerType: String?

  /// Whether the plan is publicly visible.
  public var publiclyVisible: Bool?

  /// The URL of the plan's avatar image.
  public var avatarUrl: String?

  /// The number of free trial days included with the plan.
  public var freeTrialDays: Int?

  /// Whether the plan offers a free trial.
  public var freeTrialEnabled: Bool?

  /// The features included in the plan.
  public var features: [BillingFeature]?

  /// The store products mapped to this plan.
  ///
  /// Populated from the plan → store product mapping configured in the Clerk Dashboard.
  /// A plan can map any number of store products per store; each product's own store
  /// configuration governs how it is billed. Use ``storeProducts(for:)`` to get the
  /// products mapped for a specific store.
  public var storeProducts: [BillingPlanStoreProduct]?

  public init(
    id: String,
    name: String,
    slug: String,
    description: String? = nil,
    fee: BillingMoneyAmount? = nil,
    annualFee: BillingMoneyAmount? = nil,
    annualMonthlyFee: BillingMoneyAmount? = nil,
    isDefault: Bool? = nil,
    isRecurring: Bool? = nil,
    hasBaseFee: Bool? = nil,
    forPayerType: String? = nil,
    publiclyVisible: Bool? = nil,
    avatarUrl: String? = nil,
    freeTrialDays: Int? = nil,
    freeTrialEnabled: Bool? = nil,
    features: [BillingFeature]? = nil,
    storeProducts: [BillingPlanStoreProduct]? = nil
  ) {
    self.id = id
    self.name = name
    self.slug = slug
    self.description = description
    self.fee = fee
    self.annualFee = annualFee
    self.annualMonthlyFee = annualMonthlyFee
    self.isDefault = isDefault
    self.isRecurring = isRecurring
    self.hasBaseFee = hasBaseFee
    self.forPayerType = forPayerType
    self.publiclyVisible = publiclyVisible
    self.avatarUrl = avatarUrl
    self.freeTrialDays = freeTrialDays
    self.freeTrialEnabled = freeTrialEnabled
    self.features = features
    self.storeProducts = storeProducts
  }
}

extension BillingPlan {
  /// Returns the store products mapped to this plan for the given store.
  public func storeProducts(for store: BillingStore) -> [BillingPlanStoreProduct] {
    storeProducts?.filter { $0.store == store } ?? []
  }

  /// Resolves the store product to purchase for the given store.
  ///
  /// With exactly one product mapped, it is the product; with several, the caller must
  /// identify the product to purchase via `productId`.
  ///
  /// - Parameters:
  ///   - store: The store to resolve a product for.
  ///   - productId: The store product identifier to select when the plan maps more than one product.
  /// - Returns: The single ``BillingPlanStoreProduct`` to purchase.
  /// - Throws: ``ClerkBillingError/storeProductNotConfigured(planId:productId:)`` when no mapped
  ///   product matches, or ``ClerkBillingError/ambiguousStoreProduct(planId:productIds:)`` when
  ///   several match and `productId` does not narrow them to one.
  func resolveStoreProduct(for store: BillingStore, productId: String? = nil) throws -> BillingPlanStoreProduct {
    var candidates = storeProducts(for: store)
    if let productId {
      candidates = candidates.filter { $0.productId == productId }
    }

    guard let candidate = candidates.first else {
      throw ClerkBillingError.storeProductNotConfigured(planId: id, productId: productId)
    }
    guard candidates.count == 1 else {
      throw ClerkBillingError.ambiguousStoreProduct(planId: id, productIds: candidates.map(\.productId))
    }
    return candidate
  }
}

/// A localized money amount for a billing plan or payment.
public struct BillingMoneyAmount: Codable, Equatable, Sendable {
  /// The amount in the currency's minor unit (for example cents).
  public var amount: Int

  /// The amount formatted for display (for example `9.99`).
  public var amountFormatted: String

  /// The ISO 4217 currency code (for example `USD`).
  public var currency: String

  /// The symbol of the currency (for example `$`).
  public var currencySymbol: String

  public init(
    amount: Int,
    amountFormatted: String,
    currency: String,
    currencySymbol: String
  ) {
    self.amount = amount
    self.amountFormatted = amountFormatted
    self.currency = currency
    self.currencySymbol = currencySymbol
  }
}

/// A feature included in a billing plan.
public struct BillingFeature: Codable, Equatable, Sendable, Identifiable {
  /// The unique identifier for the feature.
  public var id: String

  /// The display name of the feature.
  public var name: String

  /// The URL-friendly identifier of the feature.
  public var slug: String

  /// The description of the feature.
  public var description: String?

  /// The URL of the feature's avatar image.
  public var avatarUrl: String?

  public init(
    id: String,
    name: String,
    slug: String,
    description: String? = nil,
    avatarUrl: String? = nil
  ) {
    self.id = id
    self.name = name
    self.slug = slug
    self.description = description
    self.avatarUrl = avatarUrl
  }
}

/// A store product mapped to a billing plan in the Clerk Dashboard.
public struct BillingPlanStoreProduct: Codable, Equatable, Sendable {
  /// The store the product belongs to.
  public var store: BillingStore

  /// The store product identifier (for example `com.acme.pro.monthly`).
  public var productId: String

  /// The store purchase option identifier, when the store models one.
  ///
  /// Google Play base plan / purchase option identifier; `nil` for App Store products.
  public var purchaseOptionId: String?

  public init(
    store: BillingStore,
    productId: String,
    purchaseOptionId: String? = nil
  ) {
    self.store = store
    self.productId = productId
    self.purchaseOptionId = purchaseOptionId
  }
}

/// An app store that can act as the payment processor for a subscription.
public enum BillingStore: Codable, Equatable, Sendable {
  /// The Apple App Store.
  case apple

  /// Google Play.
  case google

  /// Represents an unknown store.
  ///
  /// The associated value captures the raw string value from the API.
  case unknown(String)

  /// The raw string value used in the API.
  public var rawValue: String {
    switch self {
    case .apple:
      "apple"
    case .google:
      "google"
    case .unknown(let value):
      value
    }
  }

  /// Creates a `BillingStore` from its raw string value.
  public init(rawValue: String) {
    switch rawValue {
    case "apple":
      self = .apple
    case "google":
      self = .google
    default:
      self = .unknown(rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self.init(rawValue: rawValue)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// The billing period of a plan price or subscription item.
public enum BillingPlanPeriod: Codable, Equatable, Sendable {
  /// Billed monthly.
  case month

  /// Billed annually.
  case annual

  /// Represents an unknown billing period.
  ///
  /// The associated value captures the raw string value from the API.
  case unknown(String)

  /// The raw string value used in the API.
  public var rawValue: String {
    switch self {
    case .month:
      "month"
    case .annual:
      "annual"
    case .unknown(let value):
      value
    }
  }

  /// Creates a `BillingPlanPeriod` from its raw string value.
  public init(rawValue: String) {
    switch rawValue {
    case "month":
      self = .month
    case "annual":
      self = .annual
    default:
      self = .unknown(rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self.init(rawValue: rawValue)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
