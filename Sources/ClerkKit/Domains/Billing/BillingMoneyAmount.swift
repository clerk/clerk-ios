//
//  BillingMoneyAmount.swift
//  Clerk
//

import Foundation

public struct BillingMoneyAmount: Codable, Equatable, Sendable {
  public var amount: Int
  public var amountFormatted: String
  public var currency: String
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

public struct BillingPerUnitTotalTier: Codable, Equatable, Sendable {
  public var quantity: Int?
  public var feePerBlock: BillingMoneyAmount
  public var total: BillingMoneyAmount

  public init(
    quantity: Int?,
    feePerBlock: BillingMoneyAmount,
    total: BillingMoneyAmount
  ) {
    self.quantity = quantity
    self.feePerBlock = feePerBlock
    self.total = total
  }
}

public struct BillingPerUnitTotal: Codable, Equatable, Sendable {
  public var name: String
  public var blockSize: Int
  public var tiers: [BillingPerUnitTotalTier]

  public init(
    name: String,
    blockSize: Int,
    tiers: [BillingPerUnitTotalTier]
  ) {
    self.name = name
    self.blockSize = blockSize
    self.tiers = tiers
  }
}
