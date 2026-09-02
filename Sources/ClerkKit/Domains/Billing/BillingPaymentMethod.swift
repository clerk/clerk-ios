//
//  BillingPaymentMethod.swift
//  Clerk
//

import Foundation

public enum BillingPaymentMethodStatus: Codable, Equatable, Sendable {
  case active
  case expired
  case disconnected
  case unknown(String)

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

  public init(from decoder: Decoder) throws {
    try self.init(rawValue: BillingUnknownString.decode(from: decoder))
  }

  public func encode(to encoder: Encoder) throws {
    try BillingUnknownString.encode(rawValue, to: encoder)
  }
}

public struct BillingPaymentMethod: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var last4: String?
  public var paymentType: String?
  public var cardType: String?
  public var isDefault: Bool?
  public var isRemovable: Bool?
  public var status: BillingPaymentMethodStatus
  public var walletType: String?
  public var expiryYear: Int?
  public var expiryMonth: Int?
  public var createdAt: Date?
  public var updatedAt: Date?

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
    self.id = id
    self.last4 = last4
    self.paymentType = paymentType
    self.cardType = cardType
    self.isDefault = isDefault
    self.isRemovable = isRemovable
    self.status = status
    self.walletType = walletType
    self.expiryYear = expiryYear
    self.expiryMonth = expiryMonth
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
