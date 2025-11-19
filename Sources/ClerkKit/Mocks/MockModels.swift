//
//  MockModels.swift
//  Clerk
//
//  Created on 2025-01-27.
//

// swiftlint:disable file_length

import Foundation

// MARK: - Clerk

public extension Clerk {
  static var mock: Clerk {
    let clerk = Clerk()
    clerk.client = .mock
    clerk.environment = .mock
    clerk.sessionsByUserId = [User.mock.id: [.mock, .mock2]]
    return clerk
  }

  static var mockSignedOut: Clerk {
    let clerk = Clerk()
    clerk.client = .mockSignedOut
    clerk.environment = .mock
    clerk.sessionsByUserId = [:]
    return clerk
  }
}

// MARK: - Client

public extension Client {
  static var mock: Client {
    Client(
      id: "1",
      signIn: .mock,
      signUp: .mock,
      sessions: [.mock, .mock2],
      lastActiveSessionId: "1",
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }

  static var mockSignedOut: Client {
    Client(
      id: "2",
      signIn: .mock,
      signUp: .mock,
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }
}

// MARK: - Auth

// MARK: Session

public extension Session {
  static var mock: Session {
    Session(
      id: "1",
      status: .active,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      abandonAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      lastActiveAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      latestActivity: .init(
        id: "1",
        browserName: "Safari",
        browserVersion: "17.1.1",
        deviceType: "iPhone",
        ipAddress: "196.172.122.88",
        city: "Detroit",
        country: "US",
        isMobile: true
      ),
      lastActiveOrganizationId: nil,
      actor: nil,
      user: .mock,
      publicUserData: nil,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      tasks: [],
      lastActiveToken: nil
    )
  }

  static var mock2: Session {
    Session(
      id: "2",
      status: .active,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      abandonAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      lastActiveAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      latestActivity: .init(
        id: "2",
        browserName: "Chrome",
        browserVersion: "119.0.0",
        deviceType: "Macintosh",
        ipAddress: "196.172.122.88",
        city: "Detroit",
        country: "US",
        isMobile: false
      ),
      lastActiveOrganizationId: nil,
      actor: nil,
      user: .mock2,
      publicUserData: nil,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      tasks: [],
      lastActiveToken: nil
    )
  }

  static var mockExpired: Session {
    Session(
      id: "1",
      status: .expired,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      abandonAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      lastActiveAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      latestActivity: nil,
      lastActiveOrganizationId: nil,
      actor: nil,
      user: .mock,
      publicUserData: nil,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      tasks: [],
      lastActiveToken: nil
    )
  }
}

// MARK: SignIn

public extension SignIn {
  static var mock: SignIn {
    SignIn(
      id: "1",
      status: .needsIdentifier,
      supportedIdentifiers: [.emailAddress, .phoneNumber],
      identifier: User.mock.emailAddresses.first?.emailAddress,
      supportedFirstFactors: [
        .mockEmailCode,
        .mockPhoneCode,
        .mockGoogle,
        .mockApple,
        .mockPasskey,
        .mockPassword,
      ],
      supportedSecondFactors: nil,
      firstFactorVerification: .mockEmailCodeUnverifiedVerification,
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )
  }
}

// MARK: SignUp

public extension SignUp {
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
      abandonAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }
}

// MARK: Verification

public extension Verification {
  static var mockEmailCodeVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "email_code",
      attempts: nil,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: nil
    )
  }

  static var mockEmailCodeUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "email_code",
      attempts: nil,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: nil
    )
  }

  static var mockPhoneCodeVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "phone_code",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: nil
    )
  }

  static var mockPhoneCodeUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "phone_code",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: nil
    )
  }

  static var mockPasskeyVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "passkey",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: "12345"
    )
  }

  static var mockPasskeyUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "passkey",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: "12345"
    )
  }

  static var mockExternalAccountVerifiedVerification: Verification {
    Verification(
      status: .verified,
      strategy: "oauth_google",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: nil,
      nonce: nil
    )
  }

  // swiftlint:disable:next identifier_name
  static var mockExternalAccountUnverifiedVerification: Verification {
    Verification(
      status: .unverified,
      strategy: "oauth_google",
      attempts: 0,
      expireAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      error: nil,
      externalVerificationRedirectUrl: "https://accounts.google.com",
      nonce: nil
    )
  }
}

// MARK: Factor

public extension Factor {
  static var mockEmailCode: Factor {
    Factor(strategy: "email_code")
  }

  static var mockPhoneCode: Factor {
    Factor(strategy: "phone_code")
  }

  static var mockGoogle: Factor {
    Factor(strategy: "oauth_google")
  }

  static var mockApple: Factor {
    Factor(strategy: "oauth_apple")
  }

  static var mockPassword: Factor {
    Factor(strategy: "password")
  }

  static var mockPasskey: Factor {
    Factor(strategy: "passkey")
  }

  static var mockResetPasswordEmailCode: Factor {
    Factor(strategy: "reset_password_email_code")
  }

  static var mockResetPasswordPhoneCode: Factor {
    Factor(strategy: "reset_password_phone_code")
  }

  static var mockTotp: Factor {
    Factor(strategy: "totp")
  }

  static var mockBackupCode: Factor {
    Factor(strategy: "backup_code")
  }
}

// MARK: Passkey

public extension Passkey {
  static var mock: Passkey {
    Passkey(
      id: "1",
      name: "iCloud Keychain",
      verification: .mockPasskeyVerifiedVerification,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      lastUsedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }
}

// MARK: TokenResource

public extension TokenResource {
  static var mock: TokenResource {
    .init(jwt: "jwt")
  }
}

// MARK: TOTPResource

public extension TOTPResource {
  static var mock: TOTPResource {
    .init(
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

// MARK: BackupCodeResource

public extension BackupCodeResource {
  static var mock: Self {
    .init(
      id: "1",
      codes: [
        "abcd",
        "efgh",
        "ijkl",
        "mnop",
        "qrst",
        "uvwx",
        "yz",
      ],
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
  }
}

// MARK: - User

public extension User {
  static var mock: Self {
    .init(
      backupCodeEnabled: true,
      createdAt: .distantPast,
      createOrganizationEnabled: true,
      createOrganizationsLimit: 0,
      deleteSelfEnabled: true,
      emailAddresses: [.mock, .mock2],
      enterpriseAccounts: [],
      externalAccounts: [.mockVerified, .mockVerified, .mockUnverified],
      firstName: "First",
      hasImage: false,
      id: "1",
      imageUrl: "",
      lastSignInAt: .now,
      lastName: "Last",
      legalAcceptedAt: .now,
      organizationMemberships: [.mockWithUserData],
      passkeys: [.mock],
      passwordEnabled: true,
      phoneNumbers: [.mock, .mock2, .mockMfa],
      primaryEmailAddressId: "1",
      primaryPhoneNumberId: "1",
      publicMetadata: nil,
      totpEnabled: false,
      twoFactorEnabled: true,
      updatedAt: .now,
      unsafeMetadata: nil,
      username: "username"
    )
  }

  static var mock2: Self {
    .init(
      backupCodeEnabled: true,
      createdAt: .distantPast,
      createOrganizationEnabled: true,
      createOrganizationsLimit: 0,
      deleteSelfEnabled: true,
      emailAddresses: [.mock],
      enterpriseAccounts: [],
      externalAccounts: [.mockVerified, .mockVerified, .mockUnverified],
      firstName: nil,
      hasImage: false,
      id: "2",
      imageUrl: "",
      lastSignInAt: .now,
      lastName: nil,
      legalAcceptedAt: .now,
      organizationMemberships: [.mockWithUserData],
      passkeys: [.mock],
      passwordEnabled: true,
      phoneNumbers: [.mock],
      primaryEmailAddressId: "1",
      primaryPhoneNumberId: "1",
      publicMetadata: nil,
      totpEnabled: true,
      twoFactorEnabled: true,
      updatedAt: .now,
      unsafeMetadata: nil,
      username: "username2"
    )
  }
}

// MARK: EmailAddress

public extension EmailAddress {
  static var mock: EmailAddress {
    EmailAddress(
      id: "1",
      emailAddress: "user@email.com",
      verification: .mockEmailCodeVerifiedVerification,
      linkedTo: nil
    )
  }

  static var mock2: EmailAddress {
    EmailAddress(
      id: "12",
      emailAddress: "user2@email.com",
      verification: .mockEmailCodeVerifiedVerification,
      linkedTo: nil
    )
  }
}

// MARK: PhoneNumber

public extension PhoneNumber {
  static var mock: PhoneNumber {
    PhoneNumber(
      id: "1",
      phoneNumber: "+15555550100",
      reservedForSecondFactor: false,
      defaultSecondFactor: false,
      verification: .mockPhoneCodeVerifiedVerification,
      linkedTo: nil,
      backupCodes: nil
    )
  }

  static var mock2: PhoneNumber {
    PhoneNumber(
      id: "2",
      phoneNumber: "+15555550101",
      reservedForSecondFactor: false,
      defaultSecondFactor: false,
      verification: .mockPhoneCodeVerifiedVerification,
      linkedTo: nil,
      backupCodes: nil
    )
  }

  static var mockMfa: PhoneNumber {
    PhoneNumber(
      id: "3",
      phoneNumber: "+15555550102",
      reservedForSecondFactor: true,
      defaultSecondFactor: true,
      verification: .mockPhoneCodeVerifiedVerification,
      linkedTo: nil,
      backupCodes: nil
    )
  }
}

// MARK: ExternalAccount

public extension ExternalAccount {
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

// MARK: - Organization

public extension Organization {
  static var mock: Self {
    .init(
      id: "1",
      name: "Organization Name",
      slug: "org-slug",
      imageUrl: "",
      hasImage: false,
      membersCount: 3,
      pendingInvitationsCount: 1,
      maxAllowedMemberships: 100,
      adminDeleteEnabled: true,
      createdAt: Date.distantPast,
      updatedAt: .now,
      publicMetadata: nil
    )
  }
}

// MARK: OrganizationMembership

public extension OrganizationMembership {
  static var mockWithUserData: Self {
    .init(
      id: "1",
      publicMetadata: "{}",
      role: "org:role",
      roleName: "Member",
      permissions: ["org:sys_memberships:read"],
      publicUserData: .init(
        firstName: "First",
        lastName: "Last",
        imageUrl: "",
        hasImage: false,
        identifier: "identifier",
        userId: "1"
      ),
      organization: .mock,
      createdAt: Date.distantPast,
      updatedAt: .now
    )
  }

  static var mockWithoutUserData: Self {
    .init(
      id: "1",
      publicMetadata: "{}",
      role: "org:role",
      roleName: "Member",
      permissions: ["org:sys_memberships:read"],
      publicUserData: nil,
      organization: .mock,
      createdAt: Date.distantPast,
      updatedAt: .now
    )
  }
}

// MARK: OrganizationInvitation

public extension OrganizationInvitation {
  static var mock: Self {
    .init(
      id: "1",
      emailAddress: EmailAddress.mock.emailAddress,
      organizationId: "1",
      publicMetadata: "{}",
      role: "org:member",
      status: "pending",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: OrganizationDomain

public extension OrganizationDomain {
  static var mock: Self {
    .init(
      id: "1",
      name: "name",
      organizationId: "1",
      enrollmentMode: "enrollment_mode",
      verification: .init(
        status: "status",
        strategy: "strategy",
        attempts: 1,
        expireAt: .distantFuture
      ),
      affiliationEmailAddress: nil,
      totalPendingInvitations: 3,
      totalPendingSuggestions: 3,
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: OrganizationMembershipRequest

public extension OrganizationMembershipRequest {
  static var mock: Self {
    .init(
      id: "1",
      organizationId: "1",
      status: "pending",
      publicUserData: nil,
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: OrganizationSuggestion

public extension OrganizationSuggestion {
  static var mock: Self {
    .init(
      id: "1",
      publicOrganizationData: .init(
        hasImage: false,
        imageUrl: "",
        name: "name",
        id: "1",
        slug: "slug"
      ),
      status: "pending",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: UserOrganizationInvitation

public extension UserOrganizationInvitation {
  static var mock: Self {
    .init(
      id: "1",
      emailAddress: "user@email.com",
      publicOrganizationData: .init(
        hasImage: true,
        imageUrl: "",
        name: "name",
        id: "1",
        slug: "slug"
      ),
      publicMetadata: "{}",
      role: "org:member",
      status: "pending",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: RoleResource

public extension RoleResource {
  static var mock: Self {
    .init(
      id: "1",
      key: "key",
      name: "name",
      description: "description",
      permissions: [.mock],
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: PermissionResource

public extension PermissionResource {
  static var mock: Self {
    .init(
      id: "1",
      key: "key",
      name: "name",
      type: "type",
      description: "description",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }
}

// MARK: - Environment

public extension Clerk.Environment {
  static var mock: Self {
    .init(
      authConfig: .mock,
      userSettings: .mock,
      displayConfig: .mock,
      fraudSettings: nil,
      commerceSettings: .mock
    )
  }
}

// MARK: AuthConfig

public extension Clerk.Environment.AuthConfig {
  static var mock: Self {
    .init(
      singleSessionMode: false
    )
  }
}

// MARK: UserSettings

public extension Clerk.Environment.UserSettings {
  static var mock: Self {
    .init(
      attributes: [
        "email_address": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: true,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: true
        ),
        "phone_number": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: true,
          firstFactors: nil,
          usedForSecondFactor: true,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: true
        ),
        "username": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: true,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "first_name": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: false,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "last_name": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: false,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "password": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: true,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "web3_wallet": .init(
          enabled: false,
          required: false,
          usedForFirstFactor: false,
          firstFactors: nil,
          usedForSecondFactor: false,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "authenticator_app": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: false,
          firstFactors: nil,
          usedForSecondFactor: true,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
        "backup_code": .init(
          enabled: true,
          required: false,
          usedForFirstFactor: false,
          firstFactors: nil,
          usedForSecondFactor: true,
          secondFactors: nil,
          verifications: nil,
          verifyAtSignUp: false
        ),
      ],
      signUp: .init(
        customActionRequired: false,
        progressive: false,
        mode: "",
        legalConsentEnabled: true
      ),
      social: [
        "oauth_google": .init(
          enabled: true,
          required: false,
          authenticatable: true,
          strategy: "oauth_google",
          notSelectable: false,
          name: "Google",
          logoUrl: ""
        ),
        "oauth_apple": .init(
          enabled: true,
          required: false,
          authenticatable: true,
          strategy: "oauth_apple",
          notSelectable: false,
          name: "Apple",
          logoUrl: ""
        ),
        "oauth_slack": .init(
          enabled: true,
          required: false,
          authenticatable: true,
          strategy: "oauth_slack",
          notSelectable: false,
          name: "Slack",
          logoUrl: ""
        ),
      ],
      actions: .init(
        deleteSelf: true,
        createOrganization: true
      ),
      passkeySettings: .init(
        allowAutofill: true,
        showSignInButton: true
      )
    )
  }
}

// MARK: DisplayConfig

public extension Clerk.Environment.DisplayConfig {
  static var mock: Self {
    .init(
      instanceEnvironmentType: .development,
      applicationName: "Acme Co",
      preferredSignInStrategy: .otp,
      supportEmail: "support@example.com",
      branded: true,
      logoImageUrl: "",
      homeUrl: "",
      privacyPolicyUrl: "privacy",
      termsUrl: "terms"
    )
  }
}

// MARK: CommerceSettings

public extension CommerceSettings {
  static var mock: Self {
    .init(
      billing: .init(
        enabled: true,
        hasPaidUserPlans: true,
        hasPaidOrgPlans: true
      )
    )
  }
}

// MARK: - Common

// MARK: DeletedObject

public extension DeletedObject {
  static var mock: DeletedObject {
    .init(
      object: "object",
      id: "1",
      deleted: true
    )
  }
}

// MARK: ClerkClientError

public extension ClerkClientError {
  static var mock: ClerkClientError {
    .init(message: "An unknown error occurred.")
  }
}

// MARK: ClerkAPIError

public extension ClerkAPIError {
  static var mock: ClerkAPIError {
    .init(
      code: "error",
      message: "An unknown error occurred.",
      longMessage: "An unknown error occurred. Please try again or contact support.",
      meta: nil,
      clerkTraceId: "1"
    )
  }
}
