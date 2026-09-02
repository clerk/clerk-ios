//
//  BillingCreditBalance.swift
//  Clerk
//

import Foundation

public struct BillingCreditBalance: Codable, Equatable, Sendable {
  public var balance: BillingMoneyAmount?

  public init(balance: BillingMoneyAmount? = nil) {
    self.balance = balance
  }
}
