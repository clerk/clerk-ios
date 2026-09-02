//
//  BillingStatement.swift
//  Clerk
//

import Foundation

public enum BillingStatementStatus: String, Codable, Equatable, Sendable {
  case open
  case closed
}

public struct BillingStatementTotals: Codable, Equatable, Sendable {
  public var subtotal: BillingMoneyAmount
  public var grandTotal: BillingMoneyAmount
  public var taxTotal: BillingMoneyAmount

  public init(
    subtotal: BillingMoneyAmount,
    grandTotal: BillingMoneyAmount,
    taxTotal: BillingMoneyAmount
  ) {
    self.subtotal = subtotal
    self.grandTotal = grandTotal
    self.taxTotal = taxTotal
  }
}

public struct BillingStatementGroup: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var timestamp: Date
  public var items: [BillingPayment]

  public init(
    id: String,
    timestamp: Date,
    items: [BillingPayment]
  ) {
    self.id = id
    self.timestamp = timestamp
    self.items = items
  }
}

public struct BillingStatement: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var totals: BillingStatementTotals
  public var status: BillingStatementStatus
  public var timestamp: Date
  public var groups: [BillingStatementGroup]

  public init(
    id: String,
    totals: BillingStatementTotals,
    status: BillingStatementStatus,
    timestamp: Date,
    groups: [BillingStatementGroup]
  ) {
    self.id = id
    self.totals = totals
    self.status = status
    self.timestamp = timestamp
    self.groups = groups
  }
}
