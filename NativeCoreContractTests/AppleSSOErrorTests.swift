@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["waitlist-existing", "waitlist-new", "transfer-verification-error", "transfer-request-error", "unrelated-signup-error", "signup-only-restricted"])
  func appleSSOPreservesErrorDetailsAndRestrictionBoundaries(scenario: String) async throws {
    let host = try AppleSSOErrorCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    do {
      let result = try await clerk.authenticateWithSSO(.init(strategy: .oauthTokenApple, start: scenario == "signup-only-restricted" ? .signUp : .auto, transferable: true))
      #expect(scenario == "waitlist-existing")
      guard case let .case1(value) = result else { Issue.record("Expected sign-in result"); return }
      #expect(value.signIn === clerk.signIn)
      #expect(clerk.signIn.status.rawValue == "complete")
    } catch let error as CoreError {
      #expect(scenario != "waitlist-existing")
      let expected = scenario == "waitlist-new" ? "sign_up_restricted_waitlist" : scenario == "signup-only-restricted" ? "sign_up_mode_restricted" : scenario == "unrelated-signup-error" ? "form_param_invalid" : "account_locked"
      let detail = try #require(error.errors.first, "Failure: \(error.code), \(error.message)")
      #expect(detail.code == expected)
      #expect(detail.message == "Apple authentication rejected")
      #expect(detail.longMessage == "Choose another sign-in method")
      #expect(detail.meta?.paramName == "token")
      #expect(!String(describing: error.details).contains("must-not-cross"))
      #expect(error.status == (scenario == "transfer-verification-error" ? nil : 403))
    }
    #expect(clerk.session == nil)
    #expect(host.base.appleIdentityCount == 1 && host.base.browserCount == 0)
    #expect(host.requests.count == (["unrelated-signup-error", "signup-only-restricted"].contains(scenario) ? 1 : 2))
    #expect(try host.body(0)["token"] == "apple-fixture-token")
    if scenario.hasPrefix("waitlist") {
      #expect(try host.body(1)["token"] == "apple-fixture-token")
      #expect(try host.body(1)["transfer"] == nil)
    }
    if scenario.hasPrefix("transfer") { #expect(try host.body(1)["transfer"] == "true") }
  }
}

@MainActor private final class AppleSSOErrorCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let scenario: String
  var requests: [JSONValue] = []
  var supported: [String] {
    base.supported
  }

  init(scenario: String) throws {
    self.scenario = scenario
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
  }

  func body(_ index: Int) throws -> [String: String] {
    guard case let .string(text) = try requests[index].object()["body"] else { return [:] }
    var components = URLComponents()
    components.percentEncodedQuery = text.replacingOccurrences(of: "+", with: "%20")
    return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let url = try #require(arguments.object()["url"]).url()
    guard url.path.contains("/sign_ins") || url.path.contains("/sign_ups") else { return try await base.perform(capability, arguments: arguments) }
    requests.append(arguments)
    let signup = url.path.contains("/sign_ups")
    let failed = signup ? scenario.hasPrefix("waitlist") || ["unrelated-signup-error", "signup-only-restricted"].contains(scenario) : scenario == "transfer-request-error"
    let code = scenario.hasPrefix("waitlist") ? "sign_up_restricted_waitlist" : scenario == "signup-only-restricted" ? "sign_up_mode_restricted" : scenario == "unrelated-signup-error" ? "form_param_invalid" : "account_locked"
    let error: JSONValue = .object(["code": .string(code), "message": .string("Apple authentication rejected"), "long_message": .string("Choose another sign-in method"), "meta": .object(["param_name": .string("token"), "password": .string("must-not-cross")])])
    var document: JSONValue
    if failed { document = .object(["errors": .array([error])]) }
    else {
      var resource = try #require(base.fixtures[signup ? "signUp" : "signIn"]).object()
      if signup {
        var verifications = try #require(resource["verifications"]).object()
        var verification = try #require(verifications["external_account"]).object()
        verification["status"] = .string("transferable")
        verification["error"] = .object(["code": .string("external_account_exists"), "message": .string("Account exists")])
        verification["strategy"] = .string("oauth_token_apple")
        verifications["external_account"] = .object(verification)
        resource["verifications"] = .object(verifications)
      } else if scenario == "transfer-verification-error" || scenario == "waitlist-new" {
        var verification = try #require(resource["first_factor_verification"]).object()
        verification["status"] = .string(scenario == "waitlist-new" ? "transferable" : "failed")
        verification["strategy"] = .string("oauth_token_apple")
        verification["error"] = scenario == "waitlist-new" ? .null : error
        resource["first_factor_verification"] = .object(verification)
      } else {
        resource["status"] = .string("complete")
        resource["created_session_id"] = .string("sess_native")
      }
      document = .object(["response": .object(resource)])
    }
    return try .object(["status": .number(failed ? 403 : 200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(document), as: UTF8.self))])
  }
}
