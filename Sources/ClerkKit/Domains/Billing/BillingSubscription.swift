//
//  BillingSubscription.swift
//  Clerk
//

import Foundation

public enum BillingSubscriptionStatus: String, Codable, Equatable, Sendable {
  case active
  case ended
  case upcoming
  case pastDue = "past_due"
}

public enum BillingSubscriptionPlanPeriod: String, Codable, Equatable, Sendable {
  case month
  case annual
}

public enum BillingDiscountEffect: String, Codable, Equatable, Sendable {
  case percentage
  case fixedAmount = "fixed_amount"
}

public enum BillingDiscountSource: String, Codable, Equatable, Sendable {
  case promotion
  case manual
  case promoCode = "promo_code"
}

public enum BillingDiscountRedemptionStatus: String, Codable, Equatable, Sendable {
  case active
  case exhausted
  case removed
}

public struct BillingProrationCreditDetail: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount
  public var cycleDaysRemaining: Int
  public var cycleDaysTotal: Int
  public var cycleRemainingPercent: Double

  public init(
    amount: BillingMoneyAmount,
    cycleDaysRemaining: Int,
    cycleDaysTotal: Int,
    cycleRemainingPercent: Double
  ) {
    self.amount = amount
    self.cycleDaysRemaining = cycleDaysRemaining
    self.cycleDaysTotal = cycleDaysTotal
    self.cycleRemainingPercent = cycleRemainingPercent
  }
}

public struct BillingPayerCredit: Codable, Equatable, Sendable {
  public var remainingBalance: BillingMoneyAmount
  public var appliedAmount: BillingMoneyAmount

  public init(
    remainingBalance: BillingMoneyAmount,
    appliedAmount: BillingMoneyAmount
  ) {
    self.remainingBalance = remainingBalance
    self.appliedAmount = appliedAmount
  }
}

public struct BillingCredits: Codable, Equatable, Sendable {
  public var proration: BillingProrationCreditDetail?
  public var payer: BillingPayerCredit?
  public var total: BillingMoneyAmount

  public init(
    proration: BillingProrationCreditDetail? = nil,
    payer: BillingPayerCredit? = nil,
    total: BillingMoneyAmount
  ) {
    self.proration = proration
    self.payer = payer
    self.total = total
  }
}

public struct BillingProrationDiscount: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount
  public var cycleDaysPassed: Int
  public var cycleDaysTotal: Int
  public var cyclePassedPercent: Double

  public init(
    amount: BillingMoneyAmount,
    cycleDaysPassed: Int,
    cycleDaysTotal: Int,
    cyclePassedPercent: Double
  ) {
    self.amount = amount
    self.cycleDaysPassed = cycleDaysPassed
    self.cycleDaysTotal = cycleDaysTotal
    self.cyclePassedPercent = cyclePassedPercent
  }
}

public struct BillingAppliedDiscount: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount
  public var discountId: String
  public var name: String
  public var effect: BillingDiscountEffect
  public var percentOff: Double?
  public var amountOff: BillingMoneyAmount?
  public var promoCode: String?
  public var cyclesRemaining: Int?
  public var durationInCycles: Int?

  public init(
    amount: BillingMoneyAmount,
    discountId: String,
    name: String,
    effect: BillingDiscountEffect,
    percentOff: Double? = nil,
    amountOff: BillingMoneyAmount? = nil,
    promoCode: String? = nil,
    cyclesRemaining: Int? = nil,
    durationInCycles: Int? = nil
  ) {
    self.amount = amount
    self.discountId = discountId
    self.name = name
    self.effect = effect
    self.percentOff = percentOff
    self.amountOff = amountOff
    self.promoCode = promoCode
    self.cyclesRemaining = cyclesRemaining
    self.durationInCycles = durationInCycles
  }
}

public struct BillingDiscountRedemption: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var subscriptionItemId: String
  public var discountId: String
  public var name: String
  public var source: BillingDiscountSource
  public var promoCode: String?
  public var effect: BillingDiscountEffect?
  public var percentOff: Double?
  public var amountOff: BillingMoneyAmount?
  public var amount: BillingMoneyAmount?
  public var cyclesRemaining: Int?
  public var cyclesApplied: Int
  public var status: BillingDiscountRedemptionStatus?
  public var redeemedAt: Date
  public var redeemedBy: String?

  public init(
    id: String,
    subscriptionItemId: String,
    discountId: String,
    name: String,
    source: BillingDiscountSource,
    promoCode: String? = nil,
    effect: BillingDiscountEffect? = nil,
    percentOff: Double? = nil,
    amountOff: BillingMoneyAmount? = nil,
    amount: BillingMoneyAmount? = nil,
    cyclesRemaining: Int? = nil,
    cyclesApplied: Int,
    status: BillingDiscountRedemptionStatus? = nil,
    redeemedAt: Date,
    redeemedBy: String? = nil
  ) {
    self.id = id
    self.subscriptionItemId = subscriptionItemId
    self.discountId = discountId
    self.name = name
    self.source = source
    self.promoCode = promoCode
    self.effect = effect
    self.percentOff = percentOff
    self.amountOff = amountOff
    self.amount = amount
    self.cyclesRemaining = cyclesRemaining
    self.cyclesApplied = cyclesApplied
    self.status = status
    self.redeemedAt = redeemedAt
    self.redeemedBy = redeemedBy
  }
}

public struct BillingDiscounts: Codable, Equatable, Sendable {
  public var proration: BillingProrationDiscount?
  public var discount: BillingAppliedDiscount?
  public var total: BillingMoneyAmount

  public init(
    proration: BillingProrationDiscount? = nil,
    discount: BillingAppliedDiscount? = nil,
    total: BillingMoneyAmount
  ) {
    self.proration = proration
    self.discount = discount
    self.total = total
  }
}

public struct BillingPeriodTotals: Codable, Equatable, Sendable {
  public var subtotal: BillingMoneyAmount
  public var baseFee: BillingMoneyAmount
  public var taxTotal: BillingMoneyAmount
  public var grandTotal: BillingMoneyAmount
  public var perUnitTotals: [BillingPerUnitTotal]?

  public init(
    subtotal: BillingMoneyAmount,
    baseFee: BillingMoneyAmount,
    taxTotal: BillingMoneyAmount,
    grandTotal: BillingMoneyAmount,
    perUnitTotals: [BillingPerUnitTotal]? = nil
  ) {
    self.subtotal = subtotal
    self.baseFee = baseFee
    self.taxTotal = taxTotal
    self.grandTotal = grandTotal
    self.perUnitTotals = perUnitTotals
  }
}

public struct BillingTotals: Codable, Equatable, Sendable {
  public var subtotal: BillingMoneyAmount
  public var baseFee: BillingMoneyAmount?
  public var taxTotal: BillingMoneyAmount
  public var grandTotal: BillingMoneyAmount
  public var totalDueAfterFreeTrial: BillingMoneyAmount?
  public var credit: BillingMoneyAmount?
  public var credits: BillingCredits?
  public var discounts: BillingDiscounts?
  public var pastDue: BillingMoneyAmount?
  public var totalDueNow: BillingMoneyAmount?
  public var perUnitTotals: [BillingPerUnitTotal]?
  public var totalsDuePerPeriod: BillingPeriodTotals?
  public var totalDuePerPeriod: BillingMoneyAmount?

  public init(
    subtotal: BillingMoneyAmount,
    baseFee: BillingMoneyAmount? = nil,
    taxTotal: BillingMoneyAmount,
    grandTotal: BillingMoneyAmount,
    totalDueAfterFreeTrial: BillingMoneyAmount? = nil,
    credit: BillingMoneyAmount? = nil,
    credits: BillingCredits? = nil,
    discounts: BillingDiscounts? = nil,
    pastDue: BillingMoneyAmount? = nil,
    totalDueNow: BillingMoneyAmount? = nil,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    totalsDuePerPeriod: BillingPeriodTotals? = nil,
    totalDuePerPeriod: BillingMoneyAmount? = nil
  ) {
    self.subtotal = subtotal
    self.baseFee = baseFee
    self.taxTotal = taxTotal
    self.grandTotal = grandTotal
    self.totalDueAfterFreeTrial = totalDueAfterFreeTrial
    self.credit = credit
    self.credits = credits
    self.discounts = discounts
    self.pastDue = pastDue
    self.totalDueNow = totalDueNow
    self.perUnitTotals = perUnitTotals
    self.totalsDuePerPeriod = totalsDuePerPeriod
    self.totalDuePerPeriod = totalDuePerPeriod
  }
}

public struct BillingSubscriptionItemSeats: Codable, Equatable, Sendable {
  public var quantity: Int?
  public var tiers: [BillingPerUnitTotalTier]?

  public init(
    quantity: Int?,
    tiers: [BillingPerUnitTotalTier]? = nil
  ) {
    self.quantity = quantity
    self.tiers = tiers
  }
}

public struct BillingSubscriptionNextPayment: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount
  public var date: Date
  public var perUnitTotals: [BillingPerUnitTotal]?
  public var totals: BillingTotals?

  public init(
    amount: BillingMoneyAmount,
    date: Date,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    totals: BillingTotals? = nil
  ) {
    self.amount = amount
    self.date = date
    self.perUnitTotals = perUnitTotals
    self.totals = totals
  }
}

public struct BillingSubscriptionItemNextPayment: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount
  public var date: Date
  public var perUnitTotals: [BillingPerUnitTotal]?
  public var totals: BillingTotals?

  public init(
    amount: BillingMoneyAmount,
    date: Date,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    totals: BillingTotals? = nil
  ) {
    self.amount = amount
    self.date = date
    self.perUnitTotals = perUnitTotals
    self.totals = totals
  }
}

public struct BillingSubscriptionItemCredit: Codable, Equatable, Sendable {
  public var amount: BillingMoneyAmount

  public init(amount: BillingMoneyAmount) {
    self.amount = amount
  }
}

public struct BillingSubscriptionItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var plan: BillingPlan
  public var planPeriod: BillingSubscriptionPlanPeriod
  public var priceId: String
  public var status: BillingSubscriptionStatus
  public var createdAt: Date
  public var pastDueAt: Date?
  public var periodStart: Date
  public var periodEnd: Date?
  public var canceledAt: Date?
  public var amount: BillingMoneyAmount?
  public var nextPayment: BillingSubscriptionItemNextPayment?
  public var credit: BillingSubscriptionItemCredit?
  public var credits: BillingCredits?
  public var appliedDiscount: BillingDiscountRedemption?
  public var seats: BillingSubscriptionItemSeats?
  public var isFreeTrial: Bool

  public init(
    id: String,
    plan: BillingPlan,
    planPeriod: BillingSubscriptionPlanPeriod,
    priceId: String,
    status: BillingSubscriptionStatus,
    createdAt: Date,
    pastDueAt: Date? = nil,
    periodStart: Date,
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
    self.id = id
    self.plan = plan
    self.planPeriod = planPeriod
    self.priceId = priceId
    self.status = status
    self.createdAt = createdAt
    self.pastDueAt = pastDueAt
    self.periodStart = periodStart
    self.periodEnd = periodEnd
    self.canceledAt = canceledAt
    self.amount = amount
    self.nextPayment = nextPayment
    self.credit = credit
    self.credits = credits
    self.appliedDiscount = appliedDiscount
    self.seats = seats
    self.isFreeTrial = isFreeTrial
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    plan = try container.decode(BillingPlan.self, forKey: .plan)
    planPeriod = try container.decode(BillingSubscriptionPlanPeriod.self, forKey: .planPeriod)
    priceId = try container.decode(String.self, forKey: .priceId)
    status = try container.decode(BillingSubscriptionStatus.self, forKey: .status)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    pastDueAt = try container.decodeIfPresent(Date.self, forKey: .pastDueAt)
    periodStart = try container.decode(Date.self, forKey: .periodStart)
    periodEnd = try container.decodeIfPresent(Date.self, forKey: .periodEnd)
    canceledAt = try container.decodeIfPresent(Date.self, forKey: .canceledAt)
    amount = try container.decodeIfPresent(BillingMoneyAmount.self, forKey: .amount)
    nextPayment = try container.decodeIfPresent(BillingSubscriptionItemNextPayment.self, forKey: .nextPayment)
    credit = try container.decodeIfPresent(BillingSubscriptionItemCredit.self, forKey: .credit)
    credits = try container.decodeIfPresent(BillingCredits.self, forKey: .credits)
    appliedDiscount = try container.decodeIfPresent(BillingDiscountRedemption.self, forKey: .appliedDiscount)
    seats = try container.decodeIfPresent(BillingSubscriptionItemSeats.self, forKey: .seats)
    isFreeTrial = try container.decodeIfPresent(Bool.self, forKey: .isFreeTrial) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case plan
    case planPeriod
    case priceId
    case status
    case createdAt
    case pastDueAt
    case periodStart
    case periodEnd
    case canceledAt
    case amount
    case nextPayment
    case credit
    case credits
    case appliedDiscount
    case seats
    case isFreeTrial
  }
}

public struct BillingSubscription: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var activeAt: Date
  public var createdAt: Date
  public var nextPayment: BillingSubscriptionNextPayment?
  public var pastDueAt: Date?
  public var status: BillingSubscriptionStatus
  public var subscriptionItems: [BillingSubscriptionItem]
  public var updatedAt: Date?
  public var eligibleForFreeTrial: Bool

  public init(
    id: String,
    activeAt: Date,
    createdAt: Date,
    nextPayment: BillingSubscriptionNextPayment? = nil,
    pastDueAt: Date? = nil,
    status: BillingSubscriptionStatus,
    subscriptionItems: [BillingSubscriptionItem] = [],
    updatedAt: Date? = nil,
    eligibleForFreeTrial: Bool = false
  ) {
    self.id = id
    self.activeAt = activeAt
    self.createdAt = createdAt
    self.nextPayment = nextPayment
    self.pastDueAt = pastDueAt
    self.status = status
    self.subscriptionItems = subscriptionItems
    self.updatedAt = updatedAt
    self.eligibleForFreeTrial = eligibleForFreeTrial
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    activeAt = try container.decode(Date.self, forKey: .activeAt)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    nextPayment = try container.decodeIfPresent(BillingSubscriptionNextPayment.self, forKey: .nextPayment)
    pastDueAt = try container.decodeIfPresent(Date.self, forKey: .pastDueAt)
    status = try container.decode(BillingSubscriptionStatus.self, forKey: .status)
    subscriptionItems = try container.decodeIfPresent([BillingSubscriptionItem].self, forKey: .subscriptionItems) ?? []
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    eligibleForFreeTrial = try container.decodeIfPresent(Bool.self, forKey: .eligibleForFreeTrial) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case activeAt
    case createdAt
    case nextPayment
    case pastDueAt
    case status
    case subscriptionItems
    case updatedAt
    case eligibleForFreeTrial
  }
}
