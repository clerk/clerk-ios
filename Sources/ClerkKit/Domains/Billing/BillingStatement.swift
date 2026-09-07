import ClerkSnapshots
import Foundation

public typealias BillingStatement = ClerkSnapshots.BillingStatement
public typealias BillingStatementTotals = ClerkSnapshots.BillingStatementTotals
public typealias BillingStatementGroup = ClerkSnapshots.BillingStatementGroup
public typealias BillingStatementStatus = ClerkSnapshots.BillingStatementStatus

extension BillingStatementTotals {
  public init(
    subtotal: BillingMoneyAmount,
    grandTotal: BillingMoneyAmount,
    taxTotal: BillingMoneyAmount
  ) {
    self.init(grandTotal: grandTotal, subtotal: subtotal, taxTotal: taxTotal)
  }
}

extension BillingStatement {
  public init(
    id: String,
    totals: BillingStatementTotals,
    status: BillingStatementStatus,
    timestamp: Date,
    groups: [BillingStatementGroup]
  ) {
    self.init(
      object: "commerce_statement",
      id: id,
      status: status,
      timestamp: Int(timestamp.timeIntervalSince1970 * 1000),
      groups: groups,
      totals: totals
    )
  }
}

extension BillingStatementGroup {
  public init(
    id: String? = nil,
    timestamp: Date,
    items: [BillingPayment]
  ) {
    self.init(
      object: "commerce_statement_group",
      timestamp: Int(timestamp.timeIntervalSince1970 * 1000),
      items: items,
      id: id ?? ""
    )
  }
}

extension BillingStatementStatus {
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
}
