//
//  BillingPaymentMethod.swift
//  Clerk
//

import Foundation

public enum BillingPaymentMethodStatus: String, Codable, Equatable, Sendable {
  case active
  case expired
  case disconnected
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
