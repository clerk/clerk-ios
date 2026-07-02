//
//  BillingSubscriptionItem.swift
//  Clerk
//

import Foundation

/// The `BillingSubscriptionItem` object describes a single plan subscription for the current user.
///
/// Subscription items are either managed by Clerk (paid via Clerk's web checkout) or by an
/// app store (paid via In-App Purchase). Check ``managedBy`` before offering cancel or update
/// affordances — store-managed items must be managed in the store's subscription settings.
public struct BillingSubscriptionItem: Codable, Equatable, Sendable, Identifiable {
  /// The unique identifier for the subscription item.
  public var id: String

  /// The current status of the subscription item.
  public var status: Status

  /// The plan the subscription item is for.
  public var plan: BillingPlan?

  /// The unique identifier of the plan the subscription item is for.
  public var planId: String?

  /// The billing period of the subscription item.
  public var planPeriod: BillingPlanPeriod?

  /// The unique identifier of the plan price the subscription item is for.
  public var priceId: String?

  /// Who manages the lifecycle of this subscription item.
  ///
  /// Defaults to ``BillingManagedBy/clerk`` when the API omits the value.
  public var managedBy: BillingManagedBy

  /// The store product identifier associated with the subscription item, if it is store-managed.
  public var storeProductId: String?

  /// The date when the subscription item was created.
  public var createdAt: Date?

  /// The start of the current billing period.
  public var periodStart: Date?

  /// The end of the current billing period.
  ///
  /// `nil` for subscription items on the free plan.
  public var periodEnd: Date?

  /// The date when the subscription item was canceled, if it has been canceled.
  public var canceledAt: Date?

  /// The date when the subscription item became past due, if it is past due.
  public var pastDueAt: Date?

  /// Whether the subscription item is in a free trial.
  public var isFreeTrial: Bool?

  public init(
    id: String,
    status: Status,
    plan: BillingPlan? = nil,
    planId: String? = nil,
    planPeriod: BillingPlanPeriod? = nil,
    priceId: String? = nil,
    managedBy: BillingManagedBy = .clerk,
    storeProductId: String? = nil,
    createdAt: Date? = nil,
    periodStart: Date? = nil,
    periodEnd: Date? = nil,
    canceledAt: Date? = nil,
    pastDueAt: Date? = nil,
    isFreeTrial: Bool? = nil
  ) {
    self.id = id
    self.status = status
    self.plan = plan
    self.planId = planId
    self.planPeriod = planPeriod
    self.priceId = priceId
    self.managedBy = managedBy
    self.storeProductId = storeProductId
    self.createdAt = createdAt
    self.periodStart = periodStart
    self.periodEnd = periodEnd
    self.canceledAt = canceledAt
    self.pastDueAt = pastDueAt
    self.isFreeTrial = isFreeTrial
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case status
    case plan
    case planId
    case planPeriod
    case priceId
    case managedBy
    case storeProductId
    case createdAt
    case periodStart
    case periodEnd
    case canceledAt
    case pastDueAt
    case isFreeTrial
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    status = try container.decode(Status.self, forKey: .status)
    plan = try container.decodeIfPresent(BillingPlan.self, forKey: .plan)
    planId = try container.decodeIfPresent(String.self, forKey: .planId)
    planPeriod = try container.decodeIfPresent(BillingPlanPeriod.self, forKey: .planPeriod)
    priceId = try container.decodeIfPresent(String.self, forKey: .priceId)
    managedBy = try container.decodeIfPresent(BillingManagedBy.self, forKey: .managedBy) ?? .clerk
    storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    periodStart = try container.decodeIfPresent(Date.self, forKey: .periodStart)
    periodEnd = try container.decodeIfPresent(Date.self, forKey: .periodEnd)
    canceledAt = try container.decodeIfPresent(Date.self, forKey: .canceledAt)
    pastDueAt = try container.decodeIfPresent(Date.self, forKey: .pastDueAt)
    isFreeTrial = try container.decodeIfPresent(Bool.self, forKey: .isFreeTrial)
  }
}

extension BillingSubscriptionItem {
  /// The status of a subscription item.
  public enum Status: Codable, Equatable, Sendable {
    /// The subscription item is active and entitlements are granted.
    case active

    /// Auto-renew has been turned off; the item remains active until the end of the current period.
    case canceled

    /// A renewal payment failed; the store or Clerk is retrying.
    case pastDue

    /// The subscription item has ended and entitlements are revoked.
    case ended

    /// The subscription item starts at a future date.
    case upcoming

    /// Represents an unknown subscription item status.
    ///
    /// The associated value captures the raw string value from the API.
    case unknown(String)

    /// The raw string value used in the API.
    public var rawValue: String {
      switch self {
      case .active:
        "active"
      case .canceled:
        "canceled"
      case .pastDue:
        "past_due"
      case .ended:
        "ended"
      case .upcoming:
        "upcoming"
      case .unknown(let value):
        value
      }
    }

    /// Creates a `Status` from its raw string value.
    public init(rawValue: String) {
      switch rawValue {
      case "active":
        self = .active
      case "canceled":
        self = .canceled
      case "past_due":
        self = .pastDue
      case "ended":
        self = .ended
      case "upcoming":
        self = .upcoming
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

  /// Whether the subscription item's lifecycle is managed by an app store rather than Clerk.
  ///
  /// Store-managed items cannot be canceled or updated through Clerk — direct the user to the
  /// store's subscription management screen instead.
  public var isStoreManaged: Bool {
    switch managedBy {
    case .apple, .google:
      true
    case .clerk, .unknown:
      false
    }
  }
}

/// Who manages the lifecycle of a subscription item.
public enum BillingManagedBy: Codable, Equatable, Sendable {
  /// Clerk manages the subscription (paid via Clerk's web checkout).
  case clerk

  /// The Apple App Store manages the subscription (paid via In-App Purchase).
  case apple

  /// Google Play manages the subscription (paid via In-App Purchase).
  case google

  /// Represents an unknown manager.
  ///
  /// The associated value captures the raw string value from the API.
  case unknown(String)

  /// The raw string value used in the API.
  public var rawValue: String {
    switch self {
    case .clerk:
      "clerk"
    case .apple:
      "apple"
    case .google:
      "google"
    case .unknown(let value):
      value
    }
  }

  /// Creates a `BillingManagedBy` from its raw string value.
  public init(rawValue: String) {
    switch rawValue {
    case "clerk":
      self = .clerk
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
