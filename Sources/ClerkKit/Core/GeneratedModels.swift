@_exported import ClerkSnapshots
import Foundation

/// Public ClerkKit name for the generated snapshot type.
public typealias PublicUserData = ClerkSnapshots.PublicUserData

/// Public ClerkKit name for the generated snapshot type.
public typealias Verification = ClerkSnapshots.Verification

/// Public ClerkKit name for the generated snapshot type.
public typealias Passkey = ClerkSnapshots.Passkey

/// Public ClerkKit name for the generated snapshot type.
public typealias EmailAddress = ClerkSnapshots.EmailAddress

/// Public ClerkKit name for the generated snapshot type.
public typealias PhoneNumber = ClerkSnapshots.PhoneNumber

/// Public ClerkKit name for the generated snapshot type.
public typealias ExternalAccount = ClerkSnapshots.ExternalAccount

/// Public ClerkKit name for the generated snapshot type.
public typealias IdentificationLink = ClerkSnapshots.IdentificationLink

/// Public ClerkKit name for the generated snapshot type.
public typealias EnterpriseAccount = ClerkSnapshots.EnterpriseAccount

/// Public ClerkKit name for the generated snapshot type.
public typealias EnterpriseAccountConnection = ClerkSnapshots.EnterpriseAccountConnection

/// Public ClerkKit name for the generated snapshot type.
public typealias EnterpriseAccountProtocol = ClerkSnapshots.EnterpriseAccountProtocol

/// Public ClerkKit name for the generated snapshot type.
public typealias OrganizationMembership = ClerkSnapshots.OrganizationMembership

/// Public ClerkKit name for the generated snapshot type.
public typealias User = ClerkSnapshots.User

/// Public ClerkKit name for the generated snapshot type.
public typealias Web3Wallet = ClerkSnapshots.Web3Wallet

/// Public ClerkKit name for the generated snapshot type.
public typealias Session = ClerkSnapshots.Session

/// Public ClerkKit name for the generated snapshot type.
public typealias SessionActivity = ClerkSnapshots.SessionActivity

/// Public ClerkKit name for the generated snapshot type.
public typealias SessionTask = ClerkSnapshots.SessionTask

/// Public ClerkKit name for the generated snapshot type.
public typealias SessionTaskKey = ClerkSnapshots.SessionTaskKey

/// Public ClerkKit name for the generated snapshot type.
public typealias SessionStatus = ClerkSnapshots.SessionStatus

/// Public ClerkKit name for the generated snapshot type.
public typealias Token = ClerkSnapshots.Token

/// Public ClerkKit name for the generated snapshot type.
public typealias ActClaim = ClerkSnapshots.ActClaim

/// Public ClerkKit name for the generated snapshot type.
public typealias SignIn = ClerkSnapshots.SignIn

/// Public ClerkKit name for the generated snapshot type.
public typealias SignInStatus = ClerkSnapshots.SignInStatus

/// Public ClerkKit name for the generated snapshot type.
public typealias SignInIdentifier = ClerkSnapshots.SignInIdentifier

/// Public ClerkKit name for the generated snapshot type.
public typealias SignInFirstFactor = ClerkSnapshots.SignInFirstFactor

/// Public ClerkKit name for the generated snapshot type.
public typealias SignInSecondFactor = ClerkSnapshots.SignInSecondFactor

/// Public ClerkKit name for the generated snapshot type.
public typealias SignInSecondFactorStrategy = ClerkSnapshots.SignInSecondFactorStrategy

/// Public ClerkKit name for the generated snapshot type.
public typealias SignUp = ClerkSnapshots.SignUp

/// Public ClerkKit name for the generated snapshot type.
public typealias SignUpStatus = ClerkSnapshots.SignUpStatus

/// Public ClerkKit name for the generated snapshot type.
public typealias SignUpVerifications = ClerkSnapshots.SignUpVerifications

/// Public ClerkKit name for the generated snapshot type.
public typealias SignUpVerification = ClerkSnapshots.SignUpVerification

/// Public ClerkKit name for the generated snapshot type.
public typealias Client = ClerkSnapshots.Client

extension ClerkSnapshots.EmailAddress {
  public init(
    id: String,
    emailAddress: String,
    verification: Verification? = nil,
    createdAt: Date = Date(timeIntervalSince1970: 0)
  ) {
    self.init(
      object: "email_address",
      emailAddress: emailAddress,
      verification: verification,
      linkedTo: [],
      matchesSsoConnection: false,
      id: id,
      createdAt: createdAt
    )
  }
}

extension ClerkSnapshots.PhoneNumber {
  public init(
    id: String,
    phoneNumber: String,
    reservedForSecondFactor: Bool,
    defaultSecondFactor: Bool,
    verification: Verification? = nil,
    backupCodes: [String]? = nil,
    createdAt: Date = Date(timeIntervalSince1970: 0)
  ) {
    self.init(
      object: "phone_number",
      id: id,
      phoneNumber: phoneNumber,
      reservedForSecondFactor: reservedForSecondFactor,
      defaultSecondFactor: defaultSecondFactor,
      linkedTo: [],
      verification: verification,
      backupCodes: backupCodes,
      createdAt: createdAt
    )
  }
}

extension ClerkSnapshots.ExternalAccount {
  public init(
    id: String,
    identificationId: String,
    provider: String,
    providerUserId: String,
    emailAddress: String,
    approvedScopes: String,
    firstName: String? = nil,
    lastName: String? = nil,
    imageUrl: String? = nil,
    username: String? = nil,
    publicMetadata: JSON,
    label: String? = nil,
    verification: Verification? = nil,
    createdAt: Date = Date(timeIntervalSince1970: 0)
  ) {
    self.init(
      object: "external_account",
      provider: provider,
      identificationId: identificationId,
      providerUserId: providerUserId,
      approvedScopes: approvedScopes,
      emailAddress: emailAddress,
      firstName: firstName ?? "",
      lastName: lastName ?? "",
      imageUrl: imageUrl ?? "",
      username: username ?? "",
      phoneNumber: "",
      publicMetadata: publicMetadata.jsonValue,
      label: label ?? "",
      verification: verification,
      id: id,
      createdAt: createdAt
    )
  }
}

extension ClerkSnapshots.User {
  public init(
    backupCodeEnabled: Bool,
    createdAt: Date,
    createOrganizationEnabled: Bool,
    createOrganizationsLimit: Int? = nil,
    deleteSelfEnabled: Bool,
    emailAddresses: [EmailAddress],
    enterpriseAccounts: [EnterpriseAccount]? = nil,
    externalAccounts: [ExternalAccount],
    firstName: String? = nil,
    hasImage: Bool,
    id: String,
    imageUrl: String,
    lastSignInAt: Date? = nil,
    lastName: String? = nil,
    legalAcceptedAt: Date? = nil,
    organizationMemberships: [OrganizationMembership]?,
    passkeys: [Passkey],
    passwordEnabled: Bool,
    phoneNumbers: [PhoneNumber],
    primaryEmailAddressId: String? = nil,
    primaryPhoneNumberId: String? = nil,
    publicMetadata: JSON? = nil,
    totpEnabled: Bool,
    twoFactorEnabled: Bool,
    updatedAt: Date,
    unsafeMetadata: JSON? = nil,
    username: String? = nil
  ) {
    self.init(
      object: "user",
      id: id,
      externalId: nil,
      primaryEmailAddressId: primaryEmailAddressId,
      primaryPhoneNumberId: primaryPhoneNumberId,
      primaryWeb3WalletId: nil,
      imageUrl: imageUrl,
      hasImage: hasImage,
      username: username,
      emailAddresses: emailAddresses,
      phoneNumbers: phoneNumbers,
      web3Wallets: [],
      externalAccounts: externalAccounts,
      enterpriseAccounts: enterpriseAccounts ?? [],
      passkeys: passkeys,
      organizationMemberships: organizationMemberships ?? [],
      passwordEnabled: passwordEnabled,
      profileImageId: "",
      firstName: firstName,
      lastName: lastName,
      totpEnabled: totpEnabled,
      backupCodeEnabled: backupCodeEnabled,
      twoFactorEnabled: twoFactorEnabled,
      publicMetadata: publicMetadata?.jsonValue ?? .object([:]),
      unsafeMetadata: unsafeMetadata?.jsonValue ?? .object([:]),
      lastSignInAt: lastSignInAt,
      createOrganizationEnabled: createOrganizationEnabled,
      createOrganizationsLimit: createOrganizationsLimit,
      deleteSelfEnabled: deleteSelfEnabled,
      legalAcceptedAt: legalAcceptedAt,
      updatedAt: updatedAt,
      createdAt: createdAt
    )
  }
}

extension ClerkSnapshots.Session {
  public typealias SessionStatus = ClerkSnapshots.SessionStatus
  public typealias Task = ClerkSnapshots.SessionTask

  public init(
    id: String,
    status: SessionStatus,
    expireAt: Date,
    abandonAt: Date,
    lastActiveAt: Date,
    latestActivity: SessionActivity? = nil,
    lastActiveOrganizationId: String? = nil,
    actor: String? = nil,
    user: User? = nil,
    publicUserData: PublicUserData? = nil,
    createdAt: Date,
    updatedAt: Date,
    tasks: [SessionTask]? = nil,
    lastActiveToken: Token? = nil,
    factorVerificationAge: [Int]? = nil
  ) {
    self.init(
      object: "session",
      id: id,
      status: status,
      factorVerificationAge: factorVerificationAge,
      expireAt: expireAt,
      abandonAt: abandonAt,
      lastActiveAt: lastActiveAt,
      lastActiveToken: lastActiveToken ?? Token(object: "token", jwt: "", id: ""),
      lastActiveOrganizationId: lastActiveOrganizationId,
      actor: actor.map { ActClaim(sub: $0) },
      tasks: tasks,
      user: user ?? .empty,
      publicUserData: publicUserData ?? PublicUserData(imageUrl: "", hasImage: false, identifier: ""),
      latestActivity: latestActivity,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension ClerkSnapshots.SessionTask {
  public static var setupMfa: SessionTask {
    SessionTask(key: .setupMfa)
  }

  public static var resetPassword: SessionTask {
    SessionTask(key: .resetPassword)
  }

  public static var chooseOrganization: SessionTask {
    SessionTask(key: .chooseOrganization)
  }

  public init(key: String) {
    self.init(key: SessionTaskKey(wire: key))
  }

  public init(rawValue: String) {
    self.init(key: rawValue)
  }

  public var rawValue: String {
    key.rawValue
  }
}

extension ClerkSnapshots.SessionTaskKey {
  public init(wire: String) {
    switch wire.lowercased() {
    case "setup-mfa":
      self = .setupMfa
    case "reset-password":
      self = .resetPassword
    case "choose-organization":
      self = .chooseOrganization
    default:
      self = .unknown(wire)
    }
  }

  public var rawValue: String {
    switch self {
    case .setupMfa:
      "setup-mfa"
    case .resetPassword:
      "reset-password"
    case .chooseOrganization:
      "choose-organization"
    case .unknown(let value):
      value
    }
  }
}

extension ClerkSnapshots.SessionStatus {
  public var rawValue: String {
    switch self {
    case .abandoned:
      "abandoned"
    case .active:
      "active"
    case .pending:
      "pending"
    case .ended:
      "ended"
    case .expired:
      "expired"
    case .removed:
      "removed"
    case .replaced:
      "replaced"
    case .revoked:
      "revoked"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "abandoned":
      self = .abandoned
    case "active":
      self = .active
    case "pending":
      self = .pending
    case "ended":
      self = .ended
    case "expired":
      self = .expired
    case "removed":
      self = .removed
    case "replaced":
      self = .replaced
    case "revoked":
      self = .revoked
    default:
      self = .unknown(rawValue)
    }
  }
}

extension ClerkSnapshots.Token {
  public init(jwt: String) {
    self.init(object: "token", jwt: jwt, id: "")
  }

  var decodedJWT: DecodedJWT? {
    do {
      return try DecodedJWT(jwt: jwt)
    } catch {
      ClerkLogger.error("Failed to decode JWT", error: error)
      return nil
    }
  }

  var featuresClaim: String {
    decodedJWT?.claim(name: "fea").string ?? ""
  }

  var plansClaim: String {
    decodedJWT?.claim(name: "pla").string ?? ""
  }
}

extension ClerkSnapshots.OrganizationMembership {
  public var permissionKeys: [String] {
    get {
      permissions.compactMap { value in
        if case .string(let key) = value { return key }
        return nil
      }
    }
    set {
      permissions = newValue.map(JSONValue.string)
    }
  }

  public init(
    id: String,
    publicMetadata: JSON,
    role: String,
    roleName: String,
    permissions: [String]?,
    publicUserData: PublicUserData? = nil,
    organization: Organization,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "organization_membership",
      id: id,
      organization: organization,
      permissions: (permissions ?? []).map(JSONValue.string),
      publicMetadata: publicMetadata.jsonValue,
      publicUserData: publicUserData,
      role: role,
      roleName: roleName,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension ClerkSnapshots.EnterpriseAccount {
  public init(
    id: String,
    object: String,
    protocol: String,
    provider: String,
    active: Bool,
    emailAddress: String,
    firstName: String? = nil,
    lastName: String? = nil,
    providerUserId: String? = nil,
    publicMetadata: JSON,
    verification: Verification? = nil,
    enterpriseConnection: EnterpriseAccountConnection
  ) {
    let accountProtocol: ClerkSnapshots.EnterpriseAccountProtocol = switch `protocol` {
    case "saml": .saml
    case "oauth": .oauth
    default: .unknown(`protocol`)
    }
    self.init(
      object: object,
      active: active,
      emailAddress: emailAddress,
      enterpriseConnection: enterpriseConnection,
      firstName: firstName,
      lastName: lastName,
      protocol: accountProtocol,
      provider: provider,
      providerUserId: providerUserId,
      publicMetadata: publicMetadata.jsonValue,
      verification: verification,
      lastAuthenticatedAt: nil,
      enterpriseConnectionId: enterpriseConnection.id,
      id: id
    )
  }
}

extension ClerkSnapshots.Passkey {
  public init(
    id: String,
    name: String,
    verification: Verification? = nil,
    createdAt: Date,
    updatedAt: Date,
    lastUsedAt: Date? = nil
  ) {
    self.init(
      object: "passkey",
      id: id,
      name: name,
      verification: verification,
      lastUsedAt: lastUsedAt,
      updatedAt: updatedAt,
      createdAt: createdAt
    )
  }
}

extension ClerkSnapshots.Verification {
  public typealias Status = VerificationStatus

  public init(
    status: VerificationStatus? = nil,
    strategy: FactorStrategy? = nil,
    attempts: Int? = nil,
    expireAt: Date? = nil,
    error: ClerkAPIError? = nil,
    externalVerificationRedirectUrl: String? = nil,
    nonce: String? = nil,
    biometricCredentialChallenge: BiometricCredentialChallenge? = nil
  ) {
    self.init(
      status: status ?? .unverified,
      verifiedAtClient: "",
      strategy: strategy?.rawValue ?? "",
      nonce: nonce,
      message: nil,
      externalVerificationRedirectUrl: externalVerificationRedirectUrl,
      attempts: attempts ?? 0,
      expireAt: expireAt ?? Date(timeIntervalSince1970: 0),
      channel: nil,
      error: error ?? .empty,
      id: "",
      object: "verification",
      trustedDeviceChallenge: biometricCredentialChallenge.flatMap {
        (try? JSONEncoder.clerkEncoder.encode($0)).flatMap { String(data: $0, encoding: .utf8) }
      } ?? ""
    )
  }

  public var factorStrategy: FactorStrategy? {
    get {
      strategy.isEmpty ? nil : FactorStrategy(rawValue: strategy)
    }
    set {
      strategy = newValue?.rawValue ?? ""
    }
  }

  public var kitError: ClerkAPIError? {
    error.code.isEmpty && error.message.isEmpty ? nil : error
  }

  public var biometricCredentialChallenge: BiometricCredentialChallenge? {
    get {
      guard !trustedDeviceChallenge.isEmpty, let data = trustedDeviceChallenge.data(using: .utf8) else { return nil }
      return try? JSONDecoder.clerkDecoder.decode(BiometricCredentialChallenge.self, from: data)
    }
    set {
      trustedDeviceChallenge = newValue.flatMap {
        (try? JSONEncoder.clerkEncoder.encode($0)).flatMap { String(data: $0, encoding: .utf8) }
      } ?? ""
    }
  }
}

extension ClerkSnapshots.UserData {
  static var empty: UserData {
    UserData(imageUrl: "", hasImage: false)
  }
}

extension ClerkSnapshots.SignIn {
  public typealias Status = SignInStatus
  public typealias Identifier = SignInIdentifier
  public typealias UserData = ClerkSnapshots.UserData

  public init(
    id: String,
    status: SignInStatus,
    supportedIdentifiers: [SignInIdentifier]? = nil,
    identifier: String? = nil,
    supportedFirstFactors: [Factor]? = nil,
    supportedSecondFactors: [Factor]? = nil,
    firstFactorVerification: Verification? = nil,
    secondFactorVerification: Verification? = nil,
    userData: UserData? = nil,
    createdSessionId: String? = nil
  ) {
    self.init(
      object: "sign_in",
      id: id,
      status: status,
      supportedIdentifiers: supportedIdentifiers ?? [],
      identifier: identifier ?? "",
      userData: userData ?? .empty,
      supportedFirstFactors: (supportedFirstFactors ?? []).map(\.signInFirstFactor),
      supportedSecondFactors: (supportedSecondFactors ?? []).map(\.signInSecondFactor),
      firstFactorVerification: firstFactorVerification,
      secondFactorVerification: secondFactorVerification,
      createdSessionId: createdSessionId
    )
  }

  public var firstFactors: [Factor] {
    supportedFirstFactors.map(Factor.init)
  }

  public var secondFactors: [Factor] {
    supportedSecondFactors.map(Factor.init)
  }
}

extension ClerkSnapshots.SignInStatus {
  public var rawValue: String {
    switch self {
    case .complete:
      "complete"
    case .needsIdentifier:
      "needs_identifier"
    case .needsFirstFactor:
      "needs_first_factor"
    case .needsSecondFactor:
      "needs_second_factor"
    case .needsNewPassword:
      "needs_new_password"
    case .needsClientTrust:
      "needs_client_trust"
    case .needsProtectCheck:
      "needs_protect_check"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "complete":
      self = .complete
    case "needs_identifier":
      self = .needsIdentifier
    case "needs_first_factor":
      self = .needsFirstFactor
    case "needs_second_factor":
      self = .needsSecondFactor
    case "needs_new_password":
      self = .needsNewPassword
    case "needs_client_trust":
      self = .needsClientTrust
    case "needs_protect_check":
      self = .needsProtectCheck
    default:
      self = .unknown(rawValue)
    }
  }
}

extension ClerkSnapshots.SignInIdentifier {
  public var rawValue: String {
    switch self {
    case .emailAddress:
      "email_address"
    case .phoneNumber:
      "phone_number"
    case .web3Wallet:
      "web3_wallet"
    case .username:
      "username"
    case .passkey:
      "passkey"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "email_address":
      self = .emailAddress
    case "phone_number":
      self = .phoneNumber
    case "web3_wallet":
      self = .web3Wallet
    case "username":
      self = .username
    case "passkey":
      self = .passkey
    default:
      self = .unknown(rawValue)
    }
  }
}

extension ClerkSnapshots.SignInSecondFactorStrategy {
  public var rawValue: String {
    switch self {
    case .emailCode:
      "email_code"
    case .emailLink:
      "email_link"
    case .phoneCode:
      "phone_code"
    case .totp:
      "totp"
    case .backupCode:
      "backup_code"
    case .passkey:
      "passkey"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "email_code":
      self = .emailCode
    case "email_link":
      self = .emailLink
    case "phone_code":
      self = .phoneCode
    case "totp":
      self = .totp
    case "backup_code":
      self = .backupCode
    case "passkey":
      self = .passkey
    default:
      self = .unknown(rawValue)
    }
  }
}

extension ClerkSnapshots.SignUp {
  public typealias Status = SignUpStatus

  public init(
    id: String,
    status: SignUpStatus,
    requiredFields: [SignUp.Field],
    optionalFields: [SignUp.Field],
    missingFields: [SignUp.Field],
    unverifiedFields: [SignUp.Field],
    verifications: [String: Verification?] = [:],
    username: String? = nil,
    emailAddress: String? = nil,
    phoneNumber: String? = nil,
    web3Wallet: String? = nil,
    passwordEnabled: Bool,
    firstName: String? = nil,
    lastName: String? = nil,
    unsafeMetadata: JSON? = nil,
    createdSessionId: String? = nil,
    createdUserId: String? = nil,
    abandonAt: Date
  ) {
    self.init(
      object: "sign_up",
      status: status,
      requiredFields: requiredFields.map(\.rawValue),
      optionalFields: optionalFields.map(\.rawValue),
      missingFields: missingFields.map(\.rawValue),
      unverifiedFields: unverifiedFields.map(\.rawValue),
      username: username,
      firstName: firstName,
      lastName: lastName,
      emailAddress: emailAddress,
      phoneNumber: phoneNumber,
      web3Wallet: web3Wallet,
      externalAccount: .object([:]),
      hasPassword: passwordEnabled,
      unsafeMetadata: unsafeMetadata?.jsonValue ?? .object([:]),
      createdSessionId: createdSessionId,
      createdUserId: createdUserId,
      abandonAt: abandonAt,
      verifications: SignUpVerifications(verifications),
      id: id
    )
  }

  public var passwordEnabled: Bool {
    get { hasPassword }
    set { hasPassword = newValue }
  }

  public var required: [SignUp.Field] {
    get { requiredFields.map(SignUp.Field.init(rawValue:)) }
    set { requiredFields = newValue.map(\.rawValue) }
  }

  public var optional: [SignUp.Field] {
    get { optionalFields.map(SignUp.Field.init(rawValue:)) }
    set { optionalFields = newValue.map(\.rawValue) }
  }

  public var missing: [SignUp.Field] {
    get { missingFields.map(SignUp.Field.init(rawValue:)) }
    set { missingFields = newValue.map(\.rawValue) }
  }

  public var unverified: [SignUp.Field] {
    get { unverifiedFields.map(SignUp.Field.init(rawValue:)) }
    set { unverifiedFields = newValue.map(\.rawValue) }
  }

  public var verificationByAttribute: [String: Verification?] {
    get {
      guard let verifications else { return [:] }
      return [
        "email_address": verifications.emailAddress.asVerification,
        "phone_number": verifications.phoneNumber.asVerification,
        "web3_wallet": verifications.web3Wallet.asVerification,
        "external_account": verifications.externalAccount,
      ]
    }
    set {
      verifications = SignUpVerifications(newValue)
    }
  }
}

extension ClerkSnapshots.SignUpStatus {
  public var rawValue: String {
    switch self {
    case .abandoned:
      "abandoned"
    case .missingRequirements:
      "missing_requirements"
    case .complete:
      "complete"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "abandoned":
      self = .abandoned
    case "missing_requirements":
      self = .missingRequirements
    case "complete":
      self = .complete
    default:
      self = .unknown(rawValue)
    }
  }
}

extension ClerkSnapshots.SignUpVerification {
  var asVerification: Verification {
    Verification(
      status: status,
      verifiedAtClient: verifiedAtClient,
      strategy: strategy,
      nonce: nonce,
      message: message,
      externalVerificationRedirectUrl: externalVerificationRedirectUrl,
      attempts: attempts,
      expireAt: expireAt,
      channel: channel,
      error: error,
      id: id,
      object: object
    )
  }
}

extension ClerkSnapshots.SignUpVerifications {
  init(_ attributes: [String: Verification?]) {
    self.init(
      emailAddress: (attributes["email_address"] ?? nil)?.asSignUpVerification ?? .empty,
      phoneNumber: (attributes["phone_number"] ?? nil)?.asSignUpVerification ?? .empty,
      web3Wallet: (attributes["web3_wallet"] ?? nil)?.asSignUpVerification ?? .empty,
      externalAccount: (attributes["external_account"] ?? nil) ?? .empty
    )
  }
}

extension ClerkSnapshots.Verification {
  var asSignUpVerification: SignUpVerification {
    SignUpVerification(
      nextAction: "",
      supportedStrategies: [],
      channel: channel,
      status: status,
      verifiedAtClient: verifiedAtClient,
      strategy: strategy,
      nonce: nonce,
      message: message,
      externalVerificationRedirectUrl: externalVerificationRedirectUrl,
      attempts: attempts,
      expireAt: expireAt,
      error: error,
      id: id,
      object: object
    )
  }
}

extension ClerkSnapshots.Client {
  public init(
    id: String,
    signIn: SignIn? = nil,
    signUp: SignUp? = nil,
    sessions: [Session],
    lastActiveSessionId: String? = nil,
    lastAuthenticationStrategy: FactorStrategy? = nil,
    updatedAt: Date
  ) {
    self.init(
      object: "client",
      id: id,
      sessions: sessions,
      signUp: signUp,
      signIn: signIn,
      lastActiveSessionId: lastActiveSessionId,
      lastAuthenticationStrategy: lastAuthenticationStrategy?.rawValue,
      createdAt: updatedAt,
      updatedAt: updatedAt
    )
  }

  public var lastUsedStrategy: FactorStrategy? {
    get {
      lastAuthenticationStrategy.map(FactorStrategy.init(rawValue:))
    }
    set {
      lastAuthenticationStrategy = newValue?.rawValue
    }
  }
}
