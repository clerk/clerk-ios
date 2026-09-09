import CryptoKit
import Foundation

@MainActor final class FixtureCapabilities: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random", "browser"]
  let fixtures: [String: JSONValue]
  var credential: String?
  var requests: [[String: JSONValue]] = []
  var browserCount = 0
  init(path: String) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: path))).object()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "storage.read" { return credential.map(JSONValue.string) ?? .null }
    if capability == "storage.write" { credential = try (args["value"] ?? .undefined).string(); return .null }
    if capability == "storage.remove" { credential = nil; return .null }
    if capability == "timer" { try await Task.sleep(for: .milliseconds((args["milliseconds"] ?? .number(0)).number())); return .null }
    if capability == "browser" {
      browserCount += 1
      precondition(args["url"] == .string("https://provider.example/authorize"))
      return .object(["callbackUrl": .string("clerk-test://sso-callback?rotating_token_nonce=native_nonce")])
    }
    guard capability == "http" else { throw CoreError(code: "unexpected_capability") }
    requests.append(args)
    let url = try (args["url"] ?? .undefined).url()
    var response: JSONValue
    if url.path.hasSuffix("/environment") { response = fixtures["environment"]! }
    else if url.path.hasSuffix("/client") { response = fixtures["client"]! }
    else {
      var resource = try fixtures[url.path.contains("sign_ins") ? "signIn" : "signUp"]!.object()
      if args["method"] == .string("GET") {
        precondition(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "rotating_token_nonce" && $0.value == "native_nonce" }) == true)
        resource["status"] = .string("complete")
        resource["created_session_id"] = .string("session_native")
      }
      response = .object(resource)
    }
    let body = try String(data: JSONEncoder().encode(JSONValue.object(["response": response])), encoding: .utf8)!
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(body)])
  }
}

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
    precondition(signIn.status.rawValue == "complete" && signIn.createdSessionId == "session_native")
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
