import ClerkSnapshots
import Foundation

public typealias BillingPaymentMethod = ClerkSnapshots.BillingPaymentMethod
public typealias BillingPaymentMethodStatus = ClerkSnapshots.BillingPaymentMethodStatus

extension BillingPaymentMethod {
  public init(
    id: String,
    last4: String? = nil,
    paymentType: String? = nil,
    cardType: String? = nil,
    isDefault: Bool? = nil,
    isRemovable: Bool? = nil,
    status: BillingPaymentMethodStatus,
    walletType: String? = nil,
    expiryYear: Int? = nil,
    expiryMonth: Int? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil
  ) {
    self.init(
      object: "commerce_payment_method",
      id: id,
      last4: last4,
      paymentType: paymentType,
      cardType: cardType,
      isDefault: isDefault,
      isRemovable: isRemovable,
      status: status,
      walletType: walletType,
      expiryYear: expiryYear,
      expiryMonth: expiryMonth,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension BillingPaymentMethodStatus {
  public var rawValue: String {
    switch self {
    case .active:
      "active"
    case .expired:
      "expired"
    case .disconnected:
      "disconnected"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "active":
      self = .active
    case "expired":
      self = .expired
    case "disconnected":
      self = .disconnected
    default:
      self = .unknown(rawValue)
    }
  }
}
