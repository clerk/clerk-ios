//
//  SignInFactor.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

/// The Factor type represents the factor verification strategy that can be used in the sign-in process.
public struct Factor: Codable, Equatable, Hashable, Sendable {
  
  /// The strategy of the factor.
  public let strategy: String
  
  /// The ID of the email address that a code or link will be sent to.
  public let emailAddressId: String?
  
  /// The ID of the phone number that a code will be sent to.
  public let phoneNumberId: String?
  
  /// The ID of the Web3 wallet that will be used to sign a message.
  public let web3WalletId: String?
  
  /// The safe identifier of the factor.
  public let safeIdentifier: String?
  
  /// Whether the factor is the primary factor.
  public let primary: Bool?
  
  public init(
    strategy: String,
    emailAddressId: String? = nil,
    phoneNumberId: String? = nil,
    web3WalletId: String? = nil,
    safeIdentifier: String? = nil,
    primary: Bool? = nil
  ) {
    self.strategy = strategy
    self.emailAddressId = emailAddressId
    self.phoneNumberId = phoneNumberId
    self.web3WalletId = web3WalletId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
  }
}

extension Factor {
  
  static var mock: Factor {
    Factor(
      strategy: "email_code",
      emailAddressId: "1",
      phoneNumberId: "1",
      web3WalletId: nil,
      safeIdentifier: User.mock.emailAddresses.first?.emailAddress,
      primary: true
    )
  }
  
}
