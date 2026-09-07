//
//  Factor.swift
//

import ClerkSnapshots
import Foundation

/// The Factor type represents the factor verification strategy that can be used in the sign-in process.
public struct Factor: Codable, Equatable, Hashable, Sendable {
  /// The strategy of the factor.
  public var strategy: FactorStrategy

  /// The ID of the email address that a code or link will be sent to.
  public var emailAddressId: String?

  /// The ID of the phone number that a code will be sent to.
  public var phoneNumberId: String?

  /// The ID of the Web3 wallet that will be used to sign a message.
  public var web3WalletId: String?

  /// The ID of the biometric credential that will be used to sign a challenge.
  public var biometricCredentialId: String?

  /// The ID of the enterprise connection that will be used for SSO.
  public var enterpriseConnectionId: String?

  /// The display name of the enterprise connection that will be used for SSO.
  public var enterpriseConnectionName: String?

  /// The safe identifier of the factor.
  public var safeIdentifier: String?

  /// Whether the factor is the primary factor.
  public var primary: Bool?

  /// Whether the factor is the default second factor.
  public var `default`: Bool?

  private enum CodingKeys: String, CodingKey {
    case strategy
    case emailAddressId
    case phoneNumberId
    case web3WalletId
    case biometricCredentialId = "trustedDeviceId"
    case enterpriseConnectionId
    case enterpriseConnectionName
    case safeIdentifier
    case primary
    case `default`
  }

  public init(
    strategy: FactorStrategy,
    emailAddressId: String? = nil,
    phoneNumberId: String? = nil,
    web3WalletId: String? = nil,
    biometricCredentialId: String? = nil,
    enterpriseConnectionId: String? = nil,
    enterpriseConnectionName: String? = nil,
    safeIdentifier: String? = nil,
    primary: Bool? = nil,
    default: Bool? = nil
  ) {
    self.strategy = strategy
    self.emailAddressId = emailAddressId
    self.phoneNumberId = phoneNumberId
    self.web3WalletId = web3WalletId
    self.biometricCredentialId = biometricCredentialId
    self.enterpriseConnectionId = enterpriseConnectionId
    self.enterpriseConnectionName = enterpriseConnectionName
    self.safeIdentifier = safeIdentifier
    self.primary = primary
    self.default = `default`
  }

  init(_ factor: SignInFirstFactor) {
    self.init(
      strategy: FactorStrategy(rawValue: factor.strategy),
      emailAddressId: factor.emailAddressId,
      phoneNumberId: factor.phoneNumberId,
      web3WalletId: factor.web3WalletId,
      enterpriseConnectionId: factor.enterpriseConnectionId,
      enterpriseConnectionName: factor.enterpriseConnectionName,
      safeIdentifier: factor.safeIdentifier,
      primary: factor.primary,
      default: factor.default
    )
  }

  init(_ factor: SignInSecondFactor) {
    self.init(
      strategy: FactorStrategy(rawValue: factor.strategy.rawValue),
      emailAddressId: factor.emailAddressId,
      phoneNumberId: factor.phoneNumberId,
      safeIdentifier: factor.safeIdentifier,
      primary: factor.primary,
      default: factor.default
    )
  }

  var signInFirstFactor: SignInFirstFactor {
    SignInFirstFactor(
      strategy: strategy.rawValue,
      emailAddressId: emailAddressId,
      safeIdentifier: safeIdentifier,
      primary: primary,
      phoneNumberId: phoneNumberId,
      default: `default`,
      web3WalletId: web3WalletId,
      enterpriseConnectionId: enterpriseConnectionId,
      enterpriseConnectionName: enterpriseConnectionName
    )
  }

  var signInSecondFactor: SignInSecondFactor {
    SignInSecondFactor(
      strategy: SignInSecondFactorStrategy(rawValue: strategy.rawValue),
      emailAddressId: emailAddressId,
      safeIdentifier: safeIdentifier,
      primary: primary,
      phoneNumberId: phoneNumberId,
      default: `default`
    )
  }
}
