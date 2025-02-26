//
//  ModelMocks.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension Client {
  
  static var mock: Client {
    return Client(
      id: "1",
      signIn: .mock,
      signUp: .mock,
      sessions: [.mock],
      lastActiveSessionId: "1",
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }
  
}

extension Session {
  
  static let mock = Session(
    id: "1",
    status: .active,
    expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    abandonAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    lastActiveAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    latestActivity: nil,
    lastActiveOrganizationId: nil,
    actor: nil,
    user: .mock,
    publicUserData: nil,
    createdAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    lastActiveToken: nil
  )
  
  static let mockExpired = Session(
    id: "1",
    status: .expired,
    expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    abandonAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    lastActiveAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    latestActivity: nil,
    lastActiveOrganizationId: nil,
    actor: nil,
    user: .mock,
    publicUserData: nil,
    createdAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890),
    lastActiveToken: nil
  )
  
}

extension SignIn {
  
  static var mock: SignIn {
    SignIn(
      id: "1",
      status: .needsIdentifier,
      supportedIdentifiers: [.emailAddress, .phoneNumber],
      identifier: User.mock.emailAddresses.first?.emailAddress,
      supportedFirstFactors: [.mock],
      supportedSecondFactors: nil,
      firstFactorVerification: .mockEmailCodeUnverifiedVerification,
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )
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

extension SignUp {
  
  static var mock: SignUp {
    SignUp(
      id: "1",
      status: .missingRequirements,
      requiredFields: [],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [],
      verifications: ["email_address": .mockPhoneCodeVerifiedVerification],
      username: User.mock.username,
      emailAddress: User.mock.emailAddresses.first?.emailAddress,
      phoneNumber: User.mock.phoneNumbers.first?.phoneNumber,
      web3Wallet: nil,
      passwordEnabled: User.mock.passwordEnabled,
      firstName: User.mock.firstName,
      lastName: User.mock.lastName,
      unsafeMetadata: nil,
      createdSessionId: nil,
      createdUserId: nil,
      abandonAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }
  
}

extension Verification {
  
  static var mockEmailCodeVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "email_code",
      attempts: nil,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: nil
    )
  }
  
  static var mockEmailCodeUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "email_code",
      attempts: nil,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: nil
    )
  }
  
  static var mockPhoneCodeVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "phone_code",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: nil
    )
  }
  
  static var mockPhoneCodeUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "phone_code",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: nil
    )
  }
  
  static var mockPasskeyVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "passkey",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: "12345"
    )
  }
  
  static var mockPasskeyUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "passkey",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: "12345"
    )
  }
  
  static var mockExternalAccountVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "oauth_google",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: "12345"
    )
  }
  
  static var mockExternalAccountUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "oauth_google",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      error: nil,
      nonce: "12345"
    )
  }
  
}

extension User {
  
  static var mock: User {
    User(
      id: "1",
      firstName: "First",
      lastName: "Last",
      username: "username",
      hasImage: false,
      imageUrl: "",
      passkeys: [.mock],
      primaryEmailAddressId: "1",
      emailAddresses: [.mock],
      primaryPhoneNumberId: "1",
      phoneNumbers: [.mock],
      externalAccounts: [.mockVerified, .mockVerified, .mockUnverified],
      enterpriseAccounts: [],
      passwordEnabled: true,
      totpEnabled: true,
      twoFactorEnabled: true,
      backupCodeEnabled: true,
      createOrganizationEnabled: true,
      createOrganizationsLimit: nil,
      deleteSelfEnabled: true,
      publicMetadata: nil,
      unsafeMetadata: nil,
      legalAcceptedAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      lastSignInAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      createdAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }
  
}

extension Passkey {
  
  static var mock: Passkey {
    Passkey(
      id: "1",
      name: "iCloud Keychain",
      verification: .mockPasskeyVerifiedVerification,
      createdAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890),
      lastUsedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }
  
}

extension EmailAddress {
  
  static var mock: EmailAddress {
    EmailAddress(
      id: "1",
      emailAddress: "user@email.com",
      verification: .mockEmailCodeVerifiedVerification,
      linkedTo: nil
    )
  }
  
}

extension PhoneNumber {
  
  static var mock: PhoneNumber {
    PhoneNumber(
      id: "1",
      phoneNumber: "15555550100",
      reservedForSecondFactor: false,
      defaultSecondFactor: false,
      verification: .mockPhoneCodeVerifiedVerification,
      linkedTo: nil,
      backupCodes: nil
    )
  }
  
}

extension ExternalAccount {
  
  static var mockVerified: ExternalAccount {
    .init(
      id: "1",
      identificationId: "1",
      provider: "oauth_google",
      providerUserId: "1",
      emailAddress: "user@gmail.com",
      approvedScopes: "email openid profile",
      firstName: "First",
      lastName: "Last",
      imageUrl: nil,
      username: "username",
      publicMetadata: "{}",
      label: nil,
      verification: .mockExternalAccountVerifiedVerification
    )
  }
  
  static var mockUnverified: ExternalAccount {
    .init(
      id: "1",
      identificationId: "1",
      provider: "oauth_google",
      providerUserId: "1",
      emailAddress: "user@gmail.com",
      approvedScopes: "email openid profile",
      firstName: "First",
      lastName: "Last",
      imageUrl: nil,
      username: "username",
      publicMetadata: "{}",
      label: nil,
      verification: .mockExternalAccountUnverifiedVerification
    )
  }
  
}

extension TOTPResource {
  
  static var mock: TOTPResource {
    .init(
      object: "totp_resource",
      id: "1",
      secret: "1234567890",
      uri: "https://mock.com/totp",
      verified: true,
      backupCodes: ["123", "456"],
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
  }
  
}

extension DeletedObject {
  
  static var mock: DeletedObject {
    .init(
      object: "object",
      id: "1",
      deleted: true
    )
  }
  
}

extension ClerkAPIError {
  
  static var mock: ClerkAPIError {
    .init(
      code: "error",
      message: "An unknown error occurred.",
      longMessage: "An unknown error occurred. Please try again or contact support.",
      meta: nil
    )
  }
  
}

extension ClerkClientError {
  
  static var mock: ClerkClientError {
    .init(message: "An unknown error occurred.")
  }
  
}
