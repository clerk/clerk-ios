//
//  BillingStatement.swift
//  Clerk
//

import Foundation

public enum BillingStatementStatus: Codable, Equatable, Sendable {
  case open
  case closed
  case unknown(String)

  public var rawValue: String {
    switch self {
    case .open:
      "open"
    case .closed:
      "closed"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "open":
      self = .open
    case "closed":
      self = .closed
    default:
      self = .unknown(rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    try self.init(rawValue: BillingUnknownString.decode(from: decoder))
  }

  public func encode(to encoder: Encoder) throws {
    try BillingUnknownString.encode(rawValue, to: encoder)
  }
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

public struct BillingStatementGroup: Codable, Equatable, Sendable {
  public var id: String?
  public var timestamp: Date
  public var items: [BillingPayment]

  public init(
    id: String? = nil,
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
