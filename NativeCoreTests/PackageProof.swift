import ClerkKit
import Foundation

@main struct PackageProof {
  @MainActor static func main() async throws {
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--credential-upgrade" {
      try await CredentialUpgradeProof.run(mode: CommandLine.arguments[2], fixture: CommandLine.arguments[3]); return
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--preview-fixtures" {
      try PreviewFixtureProof.run(directory: CommandLine.arguments[2]); return
    }
    guard let path = Bundle.module.url(forResource: "fapi", withExtension: "json", subdirectory: "Fixtures") else { fatalError("Missing fixtures") }
    let capabilities = try FixtureCapabilities(data: Data(contentsOf: path))
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!)
    let clerk = try await Clerk.connect(configuration: configuration, capabilities: capabilities)
    defer { clerk.close() }
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
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    precondition(clerk.signIn.status.rawValue == "complete" && clerk.session == nil)
    try await clerk.signUp.sso(.init(strategy: "oauth_google"))
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
    try await clerk.signOut()
    precondition(clerk.session == nil && clerk.user == nil)
    print("PASS: packaged ClerkKit bundle, future SSO, local reset, explicit finalization, getToken, typed errors, returned resources, explicit recovery-code reads, and sign-out")
  }
}
