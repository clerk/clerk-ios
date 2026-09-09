import ClerkKit
import Foundation

@main struct PackageProof {
  @MainActor static func main() async throws {
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--credential-upgrade" {
      try await CredentialUpgradeProof.run(mode: CommandLine.arguments[2], fixture: CommandLine.arguments[3]); return
    }
    guard let path = Bundle.module.url(forResource: "fapi", withExtension: "json", subdirectory: "Fixtures") else { fatalError("Missing fixtures") }
    let capabilities = try FixtureCapabilities(data: Data(contentsOf: path))
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!)
    let clerk = try await Clerk.connect(configuration: configuration, capabilities: capabilities)
    defer { clerk.close() }
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
    try await clerk.signOut()
    precondition(clerk.session == nil && clerk.user == nil)
    print("PASS: packaged ClerkKit bundle, future SSO, local reset, explicit finalization, getToken, and sign-out")
  }
}
