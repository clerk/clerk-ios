import CryptoKit
import Foundation

@main struct EngineProof {
  @MainActor static func main() async throws {
    let bundle = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let capabilities = try FixtureCapabilities(path: CommandLine.arguments[2])
    let transport = JavaScriptCoreTransport(capabilities: capabilities)
    let runtime = CoreRuntime(transport: transport)
    let receive = transport.receive
    transport.receive = { message in
      if let kind = try? message.object()["kind"]?.string(), kind == "runtimeError" || kind == "initializationFailed" { print("Engine error:", message) }
      receive?(message)
    }
    let started = Date()
    try await transport.start(bundle: bundle, sha256: SHA256.hash(data: bundle).map { String(format: "%02x", $0) }.joined())
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    try await runtime.initialize(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!, platform: "ios", capabilities: capabilities.supported)
    let clerk = try runtime.root("clerk", as: Clerk.self)!
    let signInRoot = try runtime.root("signIn", as: SignIn.self)!
    precondition(clerk.signIn === signInRoot)
    let signIn = clerk.signIn
    try await signIn.sso(.init(strategy: .oauthGoogle))
    precondition(signIn.status.rawValue == "complete" && signIn.createdSessionId == "sess_native")
    precondition(clerk.session == nil)
    try await clerk.signUp.sso(.init(strategy: "oauth_google"))
    precondition(clerk.signUp.status.rawValue == "complete" && clerk.session == nil)
    precondition(capabilities.browserCount == 2)
    precondition(capabilities.requests.filter { (try? $0["url"]?.string().contains("/sessions")) == true }.isEmpty)
    let oldGroup = signIn.emailCode
    let requestsBeforeReset = capabilities.requests.count
    try await signIn.reset()
    precondition(capabilities.requests.count == requestsBeforeReset)
    precondition(oldGroup.isInvalidated)
    do { try await oldGroup.verifyCode(.init(code: "123456")); preconditionFailure("Stale group accepted") }
    catch let error as CoreError { precondition(error.code == "stale_resource") }
    print("PASS: generated Swift API -> JavaScriptCore -> real future SSO; state before completion; no implicit activation; local reset; stale nested group. Elapsed \(Int(Date().timeIntervalSince(started) * 1000)) ms")
    runtime.close()
  }
}
