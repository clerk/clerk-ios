@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["valid", "missing", "nested", "empty", "whitespace", "number", "missing-id", "invalid-id"])
  func passkeyAssertionOptions(scenario: String) async throws {
    let host = try PasskeyOptionsCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let signIn = clerk.signIn
    do {
      _ = try await signIn.passkey(.init(flow: .discoverable))
      Issue.record("Expected assertion failure")
    } catch let error as CoreError {
      #expect(error.passkeyStage == (scenario.hasSuffix("-id") ? "preparingFirstFactor" : "requestingAuthorization"))
      if !scenario.hasSuffix("-id") {
        #expect(error.code == (scenario == "valid" ? "user_cancelled" : "invalid_credential_options"))
      }
    }
    #expect(host.presentations == (scenario == "valid" ? 1 : 0))
    #expect(host.paths == ["/v1/client/sign_ins"])
    #expect(clerk.signIn === signIn)
    #expect(signIn.status.rawValue == "needs_first_factor")
    #expect(clerk.session == nil && clerk.user == nil)
  }
}

@MainActor private final class PasskeyOptionsCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var presentations = 0
  var paths: [String] = []
  let options: [String: JSONValue]

  init(scenario: String) throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["client"]
    var options = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"challenge":"Y2hhbGxlbmdl","rpId":"passkeys.example.com","timeout":45000,"userVerification":"preferred","allowCredentials":[{"type":"public-key","id":"Y3JlZGVudGlhbDE","transports":["internal","hybrid"]},{"type":"public-key","id":"Y3JlZGVudGlhbDI"}]}"#.utf8)).object()
    switch scenario {
    case "missing", "nested": options.removeValue(forKey: "rpId")
    case "empty": options["rpId"] = .string("")
    case "whitespace": options["rpId"] = .string("  ")
    case "number": options["rpId"] = .number(123)
    default: break
    }
    if scenario == "nested" { options["rp"] = .object(["id": .string("passkeys.example.com")]) }
    if scenario.hasSuffix("-id") {
      var malformed: [String: JSONValue] = ["type": .string("public-key")]
      if scenario == "invalid-id" { malformed["id"] = .string("!!!") }
      options["allowCredentials"] = try .array([#require(options["allowCredentials"]).array()[0], .object(malformed)])
    }
    self.options = options
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "passkeys.get" {
      presentations += 1
      #expect(args["rpId"] == .string("passkeys.example.com"))
      #expect(args["timeout"] == .number(45000))
      #expect(args["userVerification"] == .string("preferred"))
      #expect(args["challenge"] == .object(["base64url": .string("Y2hhbGxlbmdl")]))
      let expected = try JSONDecoder().decode(JSONValue.self, from: Data(#"[{"type":"public-key","id":{"base64url":"Y3JlZGVudGlhbDE"},"transports":["internal","hybrid"]},{"type":"public-key","id":{"base64url":"Y3JlZGVudGlhbDI"}}]"#.utf8))
      #expect(args["allowCredentials"] == expected)
      throw CoreError(code: "user_cancelled")
    }
    if capability == "http", let url = try args["url"]?.url(), url.path.contains("/sign_ins") {
      paths.append(url.path)
      #expect(url.path == "/v1/client/sign_ins" && args["method"] == .string("POST"))
      var signIn = try #require(base.fixtures["signIn"]).object()
      signIn["status"] = .string("needs_first_factor")
      signIn["supported_first_factors"] = .array([.object(["strategy": .string("passkey")])])
      var verification = try #require(signIn["first_factor_verification"]).object()
      verification["strategy"] = .string("passkey")
      verification["nonce"] = try .string(#require(String(data: JSONEncoder().encode(JSONValue.object(options)), encoding: .utf8)))
      signIn["first_factor_verification"] = .object(verification)
      let body = try #require(String(data: JSONEncoder().encode(JSONValue.object(["response": .object(signIn)])), encoding: .utf8))
      return .object(["status": .number(200), "headers": .object([:]), "body": .string(body)])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
