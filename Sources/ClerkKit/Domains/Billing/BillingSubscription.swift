import ClerkSnapshots
import Foundation

public typealias BillingSubscription = ClerkSnapshots.BillingSubscription
public typealias BillingSubscriptionItem = ClerkSnapshots.BillingSubscriptionItem
public typealias BillingSubscriptionItemSeats = ClerkSnapshots.BillingSubscriptionItemSeats
public typealias BillingSubscriptionItemCredit = ClerkSnapshots.BillingSubscriptionItemCredit
public typealias BillingSubscriptionNextPayment = ClerkSnapshots.BillingSubscriptionNextPayment
public typealias BillingSubscriptionItemNextPayment = ClerkSnapshots.BillingSubscriptionItemNextPayment
public typealias BillingSubscriptionStatus = ClerkSnapshots.BillingSubscriptionStatus
public typealias BillingSubscriptionItemStatus = ClerkSnapshots.BillingSubscriptionItemStatus
public typealias BillingCheckoutPlanPeriod = ClerkSnapshots.BillingCheckoutPlanPeriod
public typealias BillingSubscriptionPlanPeriod = ClerkSnapshots.BillingCheckoutPlanPeriod
public typealias BillingCredits = ClerkSnapshots.BillingCredits
public typealias BillingProrationCreditDetail = ClerkSnapshots.BillingProrationCreditDetail
public typealias BillingPayerCredit = ClerkSnapshots.BillingPayerCredit
public typealias BillingProrationDiscount = ClerkSnapshots.BillingProrationDiscount
public typealias BillingAppliedDiscount = ClerkSnapshots.BillingAppliedDiscount
public typealias BillingDiscountRedemption = ClerkSnapshots.BillingDiscountRedemption
public typealias BillingDiscounts = ClerkSnapshots.BillingDiscounts
public typealias BillingPeriodTotals = ClerkSnapshots.BillingPeriodTotals
public typealias BillingTotals = ClerkSnapshots.BillingTotals
public typealias BillingDiscountRedemptionEffect = ClerkSnapshots.BillingDiscountRedemptionEffect
public typealias BillingDiscountRedemptionSource = ClerkSnapshots.BillingDiscountRedemptionSource
public typealias BillingDiscountRedemptionStatus = ClerkSnapshots.BillingDiscountRedemptionStatus
public typealias BillingDiscountEffect = ClerkSnapshots.BillingDiscountRedemptionEffect
public typealias BillingDiscountSource = ClerkSnapshots.BillingDiscountRedemptionSource

extension BillingSubscription {
  public init(
    id: String,
    activeAt: Date? = nil,
    createdAt: Date,
    nextPayment: BillingSubscriptionNextPayment? = nil,
    pastDueAt: Date? = nil,
    status: BillingSubscriptionStatus,
    subscriptionItems: [BillingSubscriptionItem] = [],
    updatedAt: Date? = nil,
    eligibleForFreeTrial: Bool = false
  ) {
    self.init(
      object: "commerce_subscription",
      id: id,
      nextPayment: nextPayment,
      status: status,
      createdAt: createdAt,
      activeAt: activeAt ?? createdAt,
      updatedAt: updatedAt,
      pastDueAt: pastDueAt,
      subscriptionItems: subscriptionItems,
      eligibleForFreeTrial: eligibleForFreeTrial
    )
  }
}

extension BillingSubscriptionItem {
  public init(
    id: String,
    plan: BillingPlan,
    planPeriod: BillingCheckoutPlanPeriod,
    priceId: String? = nil,
    status: BillingSubscriptionItemStatus,
    createdAt: Date? = nil,
    pastDueAt: Date? = nil,
    periodStart: Date? = nil,
    periodEnd: Date? = nil,
    canceledAt: Date? = nil,
    amount: BillingMoneyAmount? = nil,
    nextPayment: BillingSubscriptionItemNextPayment? = nil,
    credit: BillingSubscriptionItemCredit? = nil,
    credits: BillingCredits? = nil,
    appliedDiscount: BillingDiscountRedemption? = nil,
    seats: BillingSubscriptionItemSeats? = nil,
    isFreeTrial: Bool = false
  ) {
    self.init(
      object: "commerce_subscription_item",
      id: id,
      amount: amount,
      credit: credit,
      seats: seats,
      credits: credits,
      appliedDiscount: appliedDiscount,
      plan: plan,
      planPeriod: planPeriod,
      priceId: priceId ?? "",
      status: status,
      createdAt: createdAt ?? Date(timeIntervalSince1970: 0),
      periodStart: periodStart.map { Int($0.timeIntervalSince1970 * 1000) } ?? 0,
      periodEnd: periodEnd.map { Int($0.timeIntervalSince1970 * 1000) },
      canceledAt: canceledAt,
      pastDueAt: pastDueAt,
      isFreeTrial: isFreeTrial,
      nextPayment: nextPayment
    )
  }
}

extension BillingSubscriptionNextPayment {
  public init(
    amount: BillingMoneyAmount,
    date: Date,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    totals: BillingTotals? = nil
  ) {
    self.init(
      amount: amount,
      date: Int(date.timeIntervalSince1970 * 1000),
      perUnitTotals: perUnitTotals,
      totals: totals
    )
  }
}

extension BillingSubscriptionItemNextPayment {
  public init(
    amount: BillingMoneyAmount,
    date: Date,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    totals: BillingTotals? = nil
  ) {
    self.init(
      amount: amount,
      date: Int(date.timeIntervalSince1970 * 1000),
      perUnitTotals: perUnitTotals,
      totals: totals
    )
  }
}

extension BillingDiscountRedemption {
  public init(
    id: String,
    subscriptionItemId: String,
    discountId: String,
    name: String,
    source: BillingDiscountRedemptionSource,
    promoCode: String? = nil,
    effect: BillingDiscountRedemptionEffect? = nil,
    percentOff: Int? = nil,
    amountOff: BillingMoneyAmount? = nil,
    amount: BillingMoneyAmount? = nil,
    cyclesRemaining: Int? = nil,
    cyclesApplied: Int,
    status: BillingDiscountRedemptionStatus? = nil,
    redeemedAt: Date,
    redeemedBy: String? = nil
  ) {
    self.init(
      object: "commerce_discount_redemption",
      id: id,
      subscriptionItemId: subscriptionItemId,
      discountId: discountId,
      name: name,
      source: source,
      promoCode: promoCode,
      effect: effect,
      percentOff: percentOff,
      amountOff: amountOff,
      amount: amount,
      cyclesRemaining: cyclesRemaining,
      cyclesApplied: cyclesApplied,
      status: status,
      redeemedAt: redeemedAt,
      redeemedBy: redeemedBy
    )
  }
}

extension BillingSubscriptionStatus {
  public var rawValue: String {
    switch self {
    case .active:
      "active"
    case .pastDue:
      "past_due"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "active":
      self = .active
    case "past_due":
      self = .pastDue
    default:
      self = .unknown(rawValue)
    }
  }
}

extension BillingSubscriptionItemStatus {
  public var rawValue: String {
    switch self {
    case .active:
      "active"
    case .ended:
      "ended"
    case .upcoming:
      "upcoming"
    case .pastDue:
      "past_due"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "active":
      self = .active
    case "ended":
      self = .ended
    case "upcoming":
      self = .upcoming
    case "past_due":
      self = .pastDue
    default:
      self = .unknown(rawValue)
    }
  }
}

extension BillingCheckoutPlanPeriod {
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
}

extension BillingDiscountRedemptionSource {
  public var rawValue: String {
    switch self {
    case .promotion:
      "promotion"
    case .manual:
      "manual"
    case .promoCode:
      "promo_code"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "promotion":
      self = .promotion
    case "manual":
      self = .manual
    case "promo_code":
      self = .promoCode
    default:
      self = .unknown(rawValue)
    }
  }
}

extension BillingDiscountRedemptionEffect {
  public var rawValue: String {
    switch self {
    case .percentage:
      "percentage"
    case .fixedAmount:
      "fixed_amount"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "percentage":
      self = .percentage
    case "fixed_amount":
      self = .fixedAmount
    default:
      self = .unknown(rawValue)
    }
  }
}

extension BillingDiscountRedemptionStatus {
  public var rawValue: String {
    switch self {
    case .active:
      "active"
    case .exhausted:
      "exhausted"
    case .removed:
      "removed"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "active":
      self = .active
    case "exhausted":
      self = .exhausted
    case "removed":
      self = .removed
    default:
      self = .unknown(rawValue)
    }
  }
}
