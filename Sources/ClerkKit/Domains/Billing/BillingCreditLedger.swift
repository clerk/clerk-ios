//
//  BillingCreditLedger.swift
//  Clerk
//

import Foundation

public struct BillingCreditLedger: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var amount: BillingMoneyAmount
  public var sourceType: String
  public var sourceId: String
  public var createdAt: Date

  public init(
    id: String,
    amount: BillingMoneyAmount,
    sourceType: String,
    sourceId: String,
    createdAt: Date
  ) {
    self.id = id
    self.amount = amount
    self.sourceType = sourceType
    self.sourceId = sourceId
    self.createdAt = createdAt
  }
}
