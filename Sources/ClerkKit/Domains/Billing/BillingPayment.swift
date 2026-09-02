//
//  BillingPayment.swift
//  Clerk
//

import Foundation

public enum BillingPaymentChargeType: String, Codable, Equatable, Sendable {
  case checkout
  case recurring
}

public enum BillingPaymentStatus: String, Codable, Equatable, Sendable {
  case pending
  case paid
  case failed
}

public struct BillingPaymentTotals: Codable, Equatable, Sendable {
  public var subtotal: BillingMoneyAmount
  public var grandTotal: BillingMoneyAmount
  public var taxTotal: BillingMoneyAmount
  public var baseFee: BillingMoneyAmount?
  public var perUnitTotals: [BillingPerUnitTotal]?
  public var discounts: BillingDiscounts?

  public init(
    subtotal: BillingMoneyAmount,
    grandTotal: BillingMoneyAmount,
    taxTotal: BillingMoneyAmount,
    baseFee: BillingMoneyAmount? = nil,
    perUnitTotals: [BillingPerUnitTotal]? = nil,
    discounts: BillingDiscounts? = nil
  ) {
    self.subtotal = subtotal
    self.grandTotal = grandTotal
    self.taxTotal = taxTotal
    self.baseFee = baseFee
    self.perUnitTotals = perUnitTotals
    self.discounts = discounts
  }
}

public struct BillingPayment: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var amount: BillingMoneyAmount
  public var paidAt: Date?
  public var failedAt: Date?
  public var updatedAt: Date
  public var paymentMethod: BillingPaymentMethod?
  public var subscriptionItem: BillingSubscriptionItem
  public var chargeType: BillingPaymentChargeType
  public var status: BillingPaymentStatus
  public var totals: BillingPaymentTotals?

  public init(
    id: String,
    amount: BillingMoneyAmount,
    paidAt: Date? = nil,
    failedAt: Date? = nil,
    updatedAt: Date,
    paymentMethod: BillingPaymentMethod? = nil,
    subscriptionItem: BillingSubscriptionItem,
    chargeType: BillingPaymentChargeType,
    status: BillingPaymentStatus,
    totals: BillingPaymentTotals? = nil
  ) {
    self.id = id
    self.amount = amount
    self.paidAt = paidAt
    self.failedAt = failedAt
    self.updatedAt = updatedAt
    self.paymentMethod = paymentMethod
    self.subscriptionItem = subscriptionItem
    self.chargeType = chargeType
    self.status = status
    self.totals = totals
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    amount = try container.decode(BillingMoneyAmount.self, forKey: .amount)
    paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)
    failedAt = try container.decodeIfPresent(Date.self, forKey: .failedAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    paymentMethod = try container.decodeIfPresent(BillingPaymentMethod.self, forKey: .paymentMethod)
    subscriptionItem = try container.decode(BillingSubscriptionItem.self, forKey: .subscriptionItem)
    chargeType = try container.decode(BillingPaymentChargeType.self, forKey: .chargeType)
    status = try container.decode(BillingPaymentStatus.self, forKey: .status)
    totals = try container.decodeIfPresent(BillingPaymentTotals.self, forKey: .totals)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case amount
    case paidAt
    case failedAt
    case updatedAt
    case paymentMethod
    case subscriptionItem
    case chargeType
    case status
    case totals
  }
}
