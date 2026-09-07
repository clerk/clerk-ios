import ClerkSnapshots
import Foundation

public typealias BillingPayment = ClerkSnapshots.BillingPayment
public typealias BillingPaymentTotals = ClerkSnapshots.BillingPaymentTotals
public typealias BillingPaymentChargeType = ClerkSnapshots.BillingPaymentChargeType
public typealias BillingPaymentStatus = ClerkSnapshots.BillingPaymentStatus

extension BillingPayment {
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
    self.init(
      object: "commerce_payment",
      id: id,
      amount: amount,
      paidAt: paidAt,
      failedAt: failedAt,
      updatedAt: updatedAt,
      paymentMethod: paymentMethod,
      subscriptionItem: subscriptionItem,
      chargeType: chargeType,
      status: status,
      totals: totals
    )
  }
}

extension BillingPaymentChargeType {
  public var rawValue: String {
    switch self {
    case .checkout:
      "checkout"
    case .recurring:
      "recurring"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "checkout":
      self = .checkout
    case "recurring":
      self = .recurring
    default:
      self = .unknown(rawValue)
    }
  }
}

extension BillingPaymentStatus {
  public var rawValue: String {
    switch self {
    case .pending:
      "pending"
    case .paid:
      "paid"
    case .failed:
      "failed"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending":
      self = .pending
    case "paid":
      self = .paid
    case "failed":
      self = .failed
    default:
      self = .unknown(rawValue)
    }
  }
}
