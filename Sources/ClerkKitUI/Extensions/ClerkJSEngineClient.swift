#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import Foundation

@MainActor
final class ClerkJSEngineClient: ClerkEngineClient {
  private let engine: ClerkJSCore.Clerk
  private let kit: ClerkKit.Clerk

  init(engine: ClerkJSCore.Clerk, kit: ClerkKit.Clerk) {
    self.engine = engine
    self.kit = kit
  }

  func signIn(identifier: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(.init(identifier: identifier))
    publish()
  }

  func signInWithEmailCode(emailAddress: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(
      .init(identifier: emailAddress, strategy: "email_code")
    )
    publish()
  }

  func signInWithPhoneCode(phoneNumber: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(
      .init(identifier: phoneNumber, strategy: "phone_code")
    )
    publish()
  }

  func signInWithPassword(identifier: String, password: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(identifier: identifier, strategy: "password", password: password)
    )
    try await activateIfComplete(signIn)
  }

  func sendEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .emailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func sendEmailLink(
    emailAddressId: String?,
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(
        strategy: .emailLink,
        emailAddressId: emailAddressId,
        redirectUrl: redirectUrl,
        codeChallenge: codeChallenge,
        codeChallengeMethod: codeChallengeMethod
      )
    )
    publish()
  }

  func sendSignUpEmailLink(
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws {
    _ = try await engine.client.signUp.prepareVerification(
      .init(
        strategy: .emailLink,
        redirectUrl: redirectUrl,
        codeChallenge: codeChallenge,
        codeChallengeMethod: codeChallengeMethod
      )
    )
    publish()
  }

  func sendPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .phoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func verifyEmailCode(_ code: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .emailCode, code: code)
    )
    try await activateIfComplete(signIn)
  }

  func verifyPhoneCode(_ code: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .phoneCode, code: code)
    )
    try await activateIfComplete(signIn)
  }

  func authenticateWithPassword(_ password: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .password, password: password)
    )
    try await activateIfComplete(signIn)
  }

  func setActive(sessionId: String, organizationId: String?) async throws {
    await loadIfNeeded()
    try await engine.setActive(.init(session: sessionId, organization: organizationId))
    publish()
  }

  func signOut(sessionId: String?) async throws {
    await loadIfNeeded()
    if let sessionId {
      try await engine.signOut(SignOutOptions(sessionId: sessionId, redirectUrl: nil))
    } else {
      try await engine.signOut()
    }
    publish()
  }

  func getToken(template: String?, skipCache: Bool) async throws -> String? {
    await loadIfNeeded()
    return try await engine.session.getToken(
      .init(template: template, skipCache: skipCache)
    )
  }

  func signUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?,
    transfer: Bool
  ) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(
        emailAddress: emailAddress,
        phoneNumber: phoneNumber,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        legalAccepted: legalAccepted,
        transfer: transfer ? true : nil
      )
    )
    try await activateIfComplete(signUp)
  }

  func sendSignUpEmailCode() async throws {
    _ = try await engine.client.signUp.prepareVerification(.init(strategy: .emailCode))
    publish()
  }

  func sendSignUpPhoneCode() async throws {
    _ = try await engine.client.signUp.prepareVerification(.init(strategy: .phoneCode))
    publish()
  }

  func verifySignUpEmailCode(_ code: String) async throws {
    let signUp = try await engine.client.signUp.attemptVerification(
      .init(strategy: .emailCode, code: code)
    )
    try await activateIfComplete(signUp)
  }

  func verifySignUpPhoneCode(_ code: String) async throws {
    let signUp = try await engine.client.signUp.attemptVerification(
      .init(strategy: .phoneCode, code: code)
    )
    try await activateIfComplete(signUp)
  }

  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws {
    await loadIfNeeded()
    try await engine.client.signIn.authenticateWithRedirect(
      .init(strategy: strategy, redirectUrl: resolvedRedirectUrl(redirectUrl), identifier: identifier)
    )
    try await activateIfCompleteAfterRedirect()
  }

  func startEnterpriseSSO(emailAddress: String, redirectUrl: String) async throws {
    await loadIfNeeded()
    let resolved = resolvedRedirectUrl(redirectUrl)
    _ = try await engine.client.signIn.create(
      .init(identifier: emailAddress, strategy: "enterprise_sso", redirectUrl: resolved)
    )
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .enterpriseSSO, redirectUrl: resolved)
    )
    publish()
  }

  func authenticateSignUpWithRedirect(strategy: String, redirectUrl: String, emailAddress: String?) async throws {
    await loadIfNeeded()
    try await engine.client.signUp.authenticateWithRedirect(
      .init(strategy: strategy, redirectUrl: resolvedRedirectUrl(redirectUrl), emailAddress: emailAddress)
    )
    try await activateIfCompleteAfterRedirect()
  }

  func signInWithTicket(_ ticket: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(strategy: "ticket", ticket: ticket)
    )
    try await activateIfComplete(signIn)
  }

  func signInWithIdToken(strategy: String, token: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(strategy: strategy, token: token)
    )
    try await activateIfComplete(signIn)
  }

  func authenticateWithIdToken(strategy _: String, token: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .oauthTokenApple, token: token)
    )
    try await activateIfComplete(signIn)
  }

  func signUpWithTicket(_ ticket: String) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(ticket: ticket, strategy: "ticket")
    )
    try await activateIfComplete(signUp)
  }

  func signUpWithIdToken(strategy: String, token: String, firstName: String?, lastName: String?) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(firstName: firstName, lastName: lastName, token: token, strategy: strategy)
    )
    try await activateIfComplete(signUp)
  }

  func createPasskeySignIn() async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(.init(strategy: "passkey"))
    publish()
  }

  func authenticateWithPasskey(autofill: Bool) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.authenticateWithPasskey(
      AuthenticateWithPasskeyParams(flow: autofill ? .autofill : nil)
    )
    try await activateIfComplete(signIn)
  }

  func sendMfaPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareSecondFactor(
      .init(strategy: .phoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func sendMfaEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareSecondFactor(
      .init(strategy: .emailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func verifyMfaCode(_ code: String, type: ClerkKit.SignIn.MfaType) async throws {
    let signIn = try await engine.client.signIn.attemptSecondFactor(
      .init(strategy: secondFactorStrategy(type), code: code)
    )
    try await activateIfComplete(signIn)
  }

  func sendResetPasswordEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .resetPasswordEmailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .resetPasswordPhoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func verifyResetPasswordCode(_ code: String, isEmail: Bool) async throws {
    _ = try await engine.client.signIn.attemptFirstFactor(
      .init(
        strategy: isEmail ? .resetPasswordEmailCode : .resetPasswordPhoneCode,
        code: code
      )
    )
    publish()
  }

  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws {
    let signIn = try await engine.client.signIn.resetPassword(
      .init(password: password, signOutOfOtherSessions: signOutOfOtherSessions)
    )
    try await activateIfComplete(signIn)
  }

  func updateSignUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?
  ) async throws {
    let signUp = try await engine.client.signUp.update(
      .init(
        emailAddress: emailAddress,
        phoneNumber: phoneNumber,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        legalAccepted: legalAccepted
      )
    )
    try await activateIfComplete(signUp)
  }

  func updateUser(
    username: String?,
    firstName: String?,
    lastName: String?,
    primaryEmailAddressId: String?,
    primaryPhoneNumberId: String?,
    unsafeMetadata: JSON?
  ) async throws {
    await loadIfNeeded()
    _ = try await engine.user.update(
      UpdateUserParams(
        username: username,
        firstName: firstName,
        lastName: lastName,
        primaryEmailAddressId: primaryEmailAddressId,
        primaryPhoneNumberId: primaryPhoneNumberId,
        primaryWeb3WalletId: nil,
        unsafeMetadata: jsonValue(unsafeMetadata)
      )
    )
    publish()
  }

  func updatePassword(currentPassword: String?, newPassword: String, signOutOfOtherSessions: Bool) async throws {
    await loadIfNeeded()
    try await engine.user.updatePassword(
      UpdateUserPasswordParams(
        newPassword: newPassword,
        currentPassword: currentPassword,
        signOutOfOtherSessions: signOutOfOtherSessions
      )
    )
    publish()
  }

  func createEmailAddress(_ emailAddress: String) async throws {
    await loadIfNeeded()
    try await engine.user.createEmailAddress(CreateEmailAddressParams(email: emailAddress))
    publish()
  }

  func createPhoneNumber(_ phoneNumber: String) async throws {
    await loadIfNeeded()
    try await engine.user.createPhoneNumber(CreatePhoneNumberParams(phoneNumber: phoneNumber))
    publish()
  }

  func createTOTP() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.createTOTP()
    publish()
    return data
  }

  func verifyTOTP(code: String) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.verifyTOTP(VerifyTOTPParams(code: code))
    publish()
    return data
  }

  func deleteUser() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.delete()
    publish()
    return data
  }

  func reloadUser() async throws {
    await loadIfNeeded()
    try await engine.user.reload()
    publish()
  }

  func updateUserMetadata(unsafeMetadata: JSON) async throws {
    await loadIfNeeded()
    try await engine.user.updateMetadata(
      UpdateUserMetadataParams(unsafeMetadata: jsonValue(unsafeMetadata))
    )
    publish()
  }

  func createBackupCodes() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.createBackupCode()
    publish()
    return data
  }

  func disableTOTP() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.disableTOTP()
    publish()
    return data
  }

  func createExternalAccount(
    strategy: String,
    redirectUrl: String?,
    additionalScopes: [String],
    oidcPrompt: String?,
    token: String?
  ) async throws -> ClerkKit.ExternalAccount {
    await loadIfNeeded()
    try await engine.user.createExternalAccount(
      .init(
        strategy: strategy,
        redirectUrl: redirectUrl,
        additionalScopes: additionalScopes.isEmpty ? nil : additionalScopes,
        oidcPrompt: oidcPrompt,
        token: token
      )
    )
    publish()
    if let account = kit.user?.externalAccounts.last(where: { account in
      account.provider == strategy || account.provider == providerName(from: strategy)
    }) {
      return account
    }
    throw ClerkClientError(message: "External account was not created.")
  }

  func createPasskey() async throws -> ClerkKit.Passkey {
    await loadIfNeeded()
    try await engine.user.createPasskey()
    publish()
    guard let passkey = kit.user?.passkeys.last else {
      throw ClerkClientError(message: "Passkey was not created.")
    }
    return passkey
  }

  func createOrganization(name: String, slug: String?) async throws -> Organization {
    await loadIfNeeded()
    let data = try await engine.createOrganization(CreateOrganizationParams(name: name, slug: slug))
    publish()
    return try decodeOrganization(data)
  }

  func getOrganization(id: String) async throws -> Organization {
    await loadIfNeeded()
    let data = try await engine.getOrganization(id)
    publish()
    return try decodeOrganization(data)
  }

  func callOrganizationMethod(id: String, method: String, args: Data) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.organization(id).call(method, args: args)
    publish()
    return data
  }

  func callUserChild(pick: String, id: String, method: String, args: Data) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.userChild(pick: pick, id: id).call(method, args: args)
    publish()
    return data
  }

  func callListedChild(
    organizationId: String?,
    locate: String,
    locateArgs: Data,
    findId: String?,
    method: String,
    args: Data
  ) async throws -> Data {
    await loadIfNeeded()
    let data: Data = if let organizationId {
      try await engine.organization(organizationId).callChild(
        locate: locate,
        locateArgs: locateArgs,
        findId: findId,
        method: method,
        args: args
      )
    } else {
      try await engine.callUserListedChild(
        locate: locate,
        locateArgs: locateArgs,
        findId: findId,
        method: method,
        args: args
      )
    }
    publish()
    return data
  }

  func callInstance(root: String, method: String, args: Data) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.callInstanceMethod(root: root, method: method, args: args)
    publish()
    return data
  }

  func getOrganizationInvitations(page: Int, pageSize: Int, status: [String]) async throws -> Data {
    await loadIfNeeded()
    return try await engine.user.getOrganizationInvitations(
      .init(initialPage: page, pageSize: pageSize, status: status)
    )
  }

  func getOrganizationMemberships(page: Int, pageSize: Int) async throws -> Data {
    await loadIfNeeded()
    return try await engine.user.getOrganizationMemberships(
      .init(initialPage: page, pageSize: pageSize)
    )
  }

  func getOrganizationSuggestions(page: Int, pageSize: Int, status: [String]) async throws -> Data {
    await loadIfNeeded()
    return try await engine.user.getOrganizationSuggestions(
      .init(initialPage: page, pageSize: pageSize, status: status)
    )
  }

  func getSessions() async throws -> Data {
    await loadIfNeeded()
    return try await engine.user.getSessions()
  }

  func leaveOrganization(organizationId: String) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.leaveOrganization(organizationId)
    publish()
    return data
  }

  func getOrganizationCreationDefaults() async throws -> Data {
    await loadIfNeeded()
    return try await engine.user.getOrganizationCreationDefaults()
  }

  func transferToSignUp(unsafeMetadata: JSON?) async throws {
    await loadIfNeeded()
    let converted = try unsafeMetadata.map {
      try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode($0))
    }
    let signUp = try await engine.client.signUp.create(
      .init(transfer: true, unsafeMetadata: converted)
    )
    try await activateIfComplete(signUp)
  }

  func transferToSignIn() async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(.init(transfer: true))
    try await activateIfComplete(signIn)
  }

  func startSessionVerification(level: String) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.startVerification(.init(level: level))
    publish()
    return try decodeSessionVerification(data)
  }

  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.prepareFirstFactorVerification(
      .init(
        strategy: strategy,
        emailAddressId: emailAddressId,
        phoneNumberId: phoneNumberId,
        enterpriseConnectionId: enterpriseConnectionId,
        redirectUrl: redirectUrl
      )
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.attemptFirstFactorVerification(
      .init(
        strategy: strategy,
        code: code,
        password: password,
        publicKeyCredential: publicKeyCredential
      )
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.prepareSecondFactorVerification(
      .init(strategy: strategy, phoneNumberId: phoneNumberId)
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.attemptSecondFactorVerification(
      .init(strategy: strategy, code: code, publicKeyCredential: publicKeyCredential)
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func verifySessionWithPasskey() async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.verifyWithPasskey()
    publish()
    return try decodeSessionVerification(data)
  }

  private func jsonValue(_ json: JSON?) throws -> JSONValue? {
    guard let json else { return nil }
    return try jsonValue(json)
  }

  private func jsonValue(_ json: JSON) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(json))
  }

  private func providerName(from strategy: String) -> String {
    strategy
      .replacingOccurrences(of: "oauth_token_", with: "")
      .replacingOccurrences(of: "oauth_", with: "")
  }

  private func decodeOrganization(_ data: Data) throws -> Organization {
    try JSONDecoder().decode(Organization.self, from: data)
  }

  private func loadIfNeeded() async {
    await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
  }

  private func publish() {
    ClerkRuntimeStore.publish(engine, onto: kit)
  }

  private func activateIfComplete(_ signIn: ClerkJSCore.Clerk.SignIn) async throws {
    if signIn.status == .complete, let sessionId = signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func activateIfComplete(_ signUp: ClerkJSCore.Clerk.SignUp) async throws {
    if let sessionId = signUp.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func activateIfCompleteAfterRedirect() async throws {
    if let sessionId = engine.client.signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    } else if let sessionId = engine.client.signUp.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func resolvedRedirectUrl(_ redirectUrl: String) -> String {
    if redirectUrl.isEmpty {
      return ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString
    }
    return redirectUrl
  }

  private func secondFactorStrategy(_ type: ClerkKit.SignIn.MfaType) -> ClerkJSCore.Clerk.SignIn.SecondFactorStrategy {
    switch type {
    case .phoneCode:
      .phoneCode
    case .emailCode:
      .emailCode
    case .totp:
      .totp
    case .backupCode:
      .backupCode
    }
  }

  private func decodeSessionVerification(_ data: Data) throws -> SessionVerification {
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ClerkClientError(message: "Session verification did not return a JSON object.")
    }

    object.removeValue(forKey: "session")
    if let status = object["status"] as? String {
      object["status"] = sessionVerificationStatusValue(status)
    }
    if let level = object["level"] as? String {
      object["level"] = sessionVerificationLevelValue(level)
    }
    normalizeFactorVerification(&object, camel: "firstFactorVerification", snake: "first_factor_verification")
    normalizeFactorVerification(&object, camel: "secondFactorVerification", snake: "second_factor_verification")

    let payload = try JSONSerialization.data(withJSONObject: object)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .millisecondsSince1970
    var verification = try decoder.decode(SessionVerification.self, from: payload)
    if verification.session == nil {
      verification.session = kit.session
    }
    return verification
  }

  private func normalizeFactorVerification(
    _ object: inout [String: Any],
    camel: String,
    snake: String
  ) {
    for key in [camel, snake] {
      guard var verification = object[key] as? [String: Any] else { continue }
      if let millis = unixMilliseconds(verification["expireAt"] ?? verification["expire_at"]) {
        verification["expireAt"] = millis
        verification["expire_at"] = millis
      }
      if let nonceObject = verification["nonce"] as? [String: Any],
        let nonceData = try? JSONSerialization.data(withJSONObject: nonceObject),
        let nonceString = String(data: nonceData, encoding: .utf8)
      {
        verification["nonce"] = nonceString
      }
      object[key] = verification
    }
  }

  private func sessionVerificationStatusValue(_ raw: String) -> String {
    switch raw {
    case "needsFirstFactor":
      "needs_first_factor"
    case "needsSecondFactor":
      "needs_second_factor"
    default:
      raw
    }
  }

  private func sessionVerificationLevelValue(_ raw: String) -> String {
    switch raw {
    case "firstFactor":
      "first_factor"
    case "secondFactor":
      "second_factor"
    case "multiFactor":
      "multi_factor"
    default:
      raw
    }
  }

  private func unixMilliseconds(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      return number.doubleValue
    case let string as String:
      let withFractional = ISO8601DateFormatter()
      withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let date = withFractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
      return date.map { $0.timeIntervalSince1970 * 1000 }
    default:
      return nil
    }
  }
}

@MainActor
enum ClerkEngineBootstrap {
  static func install() {
    guard Clerk.makeEngineClient == nil else { return }
    Clerk.makeEngineClient = { kit in
      let engine = ClerkRuntimeStore.shared(for: kit.publishableKey)
      await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
      return ClerkJSEngineClient(engine: engine, kit: kit)
    }
  }
}

@MainActor
@objc(ClerkEngineBootstrapMarker)
final class ClerkEngineBootstrapMarker: NSObject {
  @objc static func installEngineFactory() {
    ClerkEngineBootstrap.install()
  }
}

#endif
