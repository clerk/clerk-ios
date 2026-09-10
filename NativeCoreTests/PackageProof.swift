import ClerkKit
import Foundation

@main struct PackageProof {
  @MainActor static func main() async throws {
    if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--live-startup" {
      try await LiveStartupProof.run(); return
    }
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--credential-upgrade" {
      try await CredentialUpgradeProof.run(mode: CommandLine.arguments[2], fixture: CommandLine.arguments[3]); return
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--preview-fixtures" {
      try PreviewFixtureProof.run(directory: CommandLine.arguments[2]); return
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--benchmark" {
      try await BenchmarkProof.run(output: CommandLine.arguments[2]); return
    }
    try await run()
  }

  static func fixtureData() throws -> Data {
    guard let path = Bundle.module.url(forResource: "fapi", withExtension: "json", subdirectory: "Fixtures") else { throw CoreError(code: "missing_fixtures") }
    return try Data(contentsOf: path)
  }

  @MainActor static func run() async throws {
    let capabilities = try FixtureCapabilities(data: fixtureData())
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!)
    let clerk = try await Clerk.connect(configuration: configuration, capabilities: capabilities)
    defer { clerk.close() }
    for request in capabilities.requests {
      let headers = try request["headers"]?.object()
      precondition(headers?["x-ios-sdk-version"] == .string(Clerk.sdkVersion))
      #if os(macOS) || targetEnvironment(macCatalyst)
      precondition(headers?["x-mobile"] == .string("0"))
      #else
      precondition(headers?["x-mobile"] == .string("1"))
      #endif
      let requestURL = try request["url"]?.string()
      precondition(requestURL?.contains("_is_native=1") == true)
    }
    capabilities.nextAuthError = .object(["errors": .array([.object([
      "code": .string("form_identifier_not_found"), "message": .string("Account not found"),
      "long_message": .string("No account was found for this identifier."),
      "meta": .object(["param_name": .string("identifier")]),
    ])])])
    do {
      try await clerk.signIn.create(.init(identifier: "missing@example.com"))
      preconditionFailure("Expected a structured Clerk error")
    } catch let error as CoreError {
      precondition(error.errors.first?.code == "form_identifier_not_found")
      precondition(error.errors.first?.meta?.paramName == "identifier")
      precondition(error.localizedDescription == "No account was found for this identifier.")
    }
    precondition(Set([clerk.signIn, clerk.signIn]).count == 1)
    capabilities.nextAuthError = .object(["errors": .array([.object(["code": .string("passkey_verification_failed"), "message": .string("Credential rejected")])])])
    do {
      try await clerk.signIn.passkey(.init(flow: .discoverable))
      preconditionFailure("Expected passkey preparation failure")
    } catch let error as CoreError {
      precondition(error.passkeyStage == "preparingFirstFactor" && error.errors.first?.code == "passkey_verification_failed")
    }
    try await clerk.signUp.create(.init(emailAddress: "test@example.com"))
    try await clerk.signUp.verifications.sendEmailLink(.init())
    precondition(capabilities.authRecord != nil)
    let emailResult = try await clerk.handleAuthCallback(URL(string: "clerk-test://sso-callback?flow_id=sua_native&approval_token=fixture_approval")!)
    guard case .case2(let emailFlow) = emailResult else { preconditionFailure("Expected sign-up callback") }
    precondition(emailFlow.signUp === clerk.signUp && clerk.signUp.status == .complete && clerk.session == nil)
    precondition(capabilities.authRecord == nil)
    let callbackId = clerk.authCallback!.id
    try await clerk.clearAuthCallback(callbackId)
    precondition(clerk.authCallback == nil)
    try await clerk.signUp.reset()
    try await clerk.signIn.sso(.init(strategy: .oauthTokenApple))
    precondition(clerk.signIn.status == .complete && clerk.session == nil)
    try await clerk.signUp.sso(.init(strategy: "oauth_token_apple"))
    precondition(clerk.signUp.status == .complete && clerk.session == nil)
    precondition(capabilities.appleIdentityCount == 2 && capabilities.browserCount == 0)
    try await clerk.signIn.reset()
    let appleFlow = try await clerk.authenticateWithSSO(.init(strategy: .oauthTokenApple, start: .auto, transferable: false))
    guard case .case1(let appleResult) = appleFlow else { preconditionFailure("Expected sign-in") }
    precondition(appleResult.signIn === clerk.signIn && appleResult.signIn.status == .complete && clerk.session == nil)
    precondition(capabilities.appleIdentityCount == 3 && capabilities.browserCount == 0)
    try await clerk.signIn.reset()
    try await clerk.signUp.reset()
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle, oidcPrompt: "consent"))
    precondition(capabilities.requests.contains { (try? $0["body"]?.string().contains("oidc_prompt=consent")) == true })
    precondition(clerk.signIn.status.rawValue == "complete" && clerk.session == nil)
    try await clerk.signUp.sso(.init(strategy: "oauth_google", oidcPrompt: "login"))
    precondition(capabilities.requests.contains { (try? $0["body"]?.string().contains("oidc_prompt=login")) == true })
    precondition(clerk.signUp.status.rawValue == "complete" && clerk.session == nil)
    let oldGroup = clerk.signIn.emailCode
    let beforeReset = capabilities.requests.count
    try await clerk.signIn.reset()
    precondition(oldGroup.isInvalidated && capabilities.requests.count == beforeReset)
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    precondition(clerk.session?.status.rawValue == "active")
    precondition(clerk.user?.id == "user_native")
    let token = try await clerk.session?.getToken()
    precondition(token?.contains("fixture_signature") == true)
    guard let user = clerk.user else { preconditionFailure("Missing user") }
    let phone = try await user.createPhoneNumber(.init(phoneNumber: "+15555550123"))
    await Task.yield()
    precondition(!phone.isInvalidated && phone.phoneNumber == "+15555550123")
    let originalCodes = try await phone.backupCodes()
    precondition(originalCodes == nil)
    let reservedPhone = try await phone.setReservedForSecondFactor(.init(reserved: true))
    precondition(reservedPhone === phone && phone.reservedForSecondFactor)
    let codes = try await phone.backupCodes()
    precondition(codes == ["fixture-recovery-code"])
    precondition(clerk.biometricCredentials.canEnroll)
    let biometric = try await clerk.biometricCredentials.enroll(.init(identifierHint: "test@example.com"))
    precondition(biometric.id == "td_native" && capabilities.biometricRecords != nil)
    try await clerk.signOut()
    precondition(clerk.session == nil && clerk.user == nil)
    try await clerk.signIn.biometricCredential()
    precondition(clerk.signIn.status == .complete && clerk.session == nil && capabilities.biometricSignCount == 2)
    print("PASS: packaged ClerkKit bundle, future SSO, local reset, explicit finalization, getToken, typed errors, returned resources, explicit recovery-code reads, and sign-out")
  }
}
