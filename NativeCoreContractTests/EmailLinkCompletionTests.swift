@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["bad-state", "null-state", "missing-ios-kind", "null-ios-kind", "valid-ios-kind", "expired-ios-kind", "valid-android", "incomplete-signIn", "incomplete-signUp", "signup-ticket"])
  func emailLinkCompletionPreservesFlowKindAndContinuation(scenario: String) async throws {
    let host = try EmailLinkCompletionCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    if !host.imported {
      if host.signup { try await clerk.signUp.verifications.sendEmailLink(.init()) }
      else { try await clerk.signIn.emailLink.sendLink(.case2(.init(emailAddressId: "idn_email"))) }
    }
    let flow = host.signup ? "sua_native" : "sia_native"
    let rejectedFlow = ["bad-state", "null-state", "expired-ios-kind"].contains(scenario)
    let expectedError = rejectedFlow ? "no_pending_email_link" : scenario == "signup-ticket" ? "invalid_email_link_response" : nil
    do {
      let callbackURL = try #require(URL(string: "clerk-test://sso-callback?flow_id=\(flow)&approval_token=fixture_approval"))
      let returned = try await clerk.handleAuthCallback(callbackURL)
      let result = try #require(returned)
      #expect(expectedError == nil)
      if host.signup {
        guard case let .case2(value) = result else { Issue.record("Expected sign-up"); return }
        #expect(value.signUp === clerk.signUp)
        #expect(clerk.signUp.status.rawValue == "missing_requirements")
        #expect(clerk.signUp.missingFields.map(\.rawValue) == ["first_name"])
        #expect(clerk.signUp.createdSessionId == nil)
      } else {
        guard case let .case1(value) = result else { Issue.record("Expected sign-in"); return }
        #expect(value.signIn === clerk.signIn)
        #expect(clerk.signIn.status.rawValue == (scenario == "incomplete-signIn" ? "needs_second_factor" : "complete"))
      }
      #expect(clerk.authCallback?.result.kind == (host.signup ? "signUp" : "signIn"))
    } catch let error as CoreError {
      #expect(expectedError != nil)
      #expect(error.code == expectedError)
      #expect(clerk.authCallback == nil)
    }
    #expect(host.base.authRecord == nil)
    #expect(clerk.session == nil)
    #expect(host.completions == (rejectedFlow ? 0 : 1))
    #expect(host.tickets == (host.signup || expectedError != nil ? 0 : 1))
  }
}

@MainActor private final class EmailLinkCompletionCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let scenario: String
  let imported: Bool
  let signup: Bool
  var completions = 0
  var tickets = 0
  let signIn: [String: JSONValue]
  let signUp: [String: JSONValue]
  var supported: [String] {
    base.supported
  }

  init(scenario: String) throws {
    self.scenario = scenario
    imported = !scenario.hasPrefix("incomplete") && scenario != "signup-ticket"
    signup = scenario == "incomplete-signUp" || scenario == "signup-ticket"
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    var client = try #require(base.fixtures["client"]).object()
    var si = try #require(base.fixtures["signIn"]).object()
    si["supported_first_factors"] = .array([.object(["strategy": .string("email_link"), "email_address_id": .string("idn_email"), "safe_identifier": .string("test@example.com")])])
    var su = try #require(base.fixtures["signUp"]).object()
    su["email_address"] = .string("test@example.com")
    signIn = si; signUp = su
    client["sign_in"] = .object(si); client["sign_up"] = .object(su)
    base.clientResponse = .object(client)
    if imported {
      let now = Date().timeIntervalSince1970 * 1000
      var record: [String: JSONValue]
      if scenario.contains("ios-kind") {
        record = ["flow_id": .string("sia_native"), "code_verifier": .string(String(repeating: "v", count: 43)), "created_at": .number(now), "expires_at": .number(now + 600_000)]
        if scenario == "null-ios-kind" { record["kind"] = .null }
        if scenario == "valid-ios-kind" || scenario == "expired-ios-kind" { record["kind"] = .string("signIn") }
        if scenario == "expired-ios-kind" { record["expires_at"] = .number(now - 1) }
      } else {
        record = ["state": scenario == "null-state" ? .null : .string(scenario == "valid-android" ? "SIGN_IN" : "UNSUPPORTED"), "flowId": .string("sia_native"), "codeVerifier": .string(String(repeating: "v", count: 43)), "createdAtEpochMs": .number(now), "expiresAtEpochMs": .number(now + 600_000)]
      }
      base.authRecord = try String(decoding: JSONEncoder().encode(JSONValue.object(record)), as: UTF8.self)
    }
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let path = try #require(arguments.object()["url"]).url().path
    var resource: JSONValue
    if path.hasSuffix("/magic_links/complete") {
      completions += 1
      if signup, scenario != "signup-ticket" {
        var su = signUp
        su["status"] = .string("missing_requirements"); su["created_session_id"] = .null
        su["missing_fields"] = .array([.string("first_name")])
        resource = .object(su)
      } else { resource = .object(["ticket": .string("fixture_ticket")]) }
    } else if path.hasSuffix("/sign_ins") {
      tickets += 1
      var si = signIn
      si["status"] = .string(scenario == "incomplete-signIn" ? "needs_second_factor" : "complete")
      si["created_session_id"] = scenario == "incomplete-signIn" ? .null : .string("sess_native")
      resource = .object(si)
    } else if path.contains("/sign_ins/") { resource = .object(signIn) }
    else if path.contains("/sign_ups/") { resource = .object(signUp) }
    else { return try await base.perform(capability, arguments: arguments) }
    let document: JSONValue = .object(["response": resource])
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(document), as: UTF8.self))])
  }
}
