@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["signIn-storage", "signIn-prepare", "signUp-storage", "signUp-prepare"])
  func emailLinkFailurePreservesVerifierBoundary(scenario: String) async throws {
    let kind = scenario.hasPrefix("signIn") ? "signIn" : "signUp"
    let storageFailure = scenario.hasSuffix("storage")
    let host = try EmailLinkFailureCapabilities(kind: kind, storageFailure: storageFailure)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    do {
      if kind == "signIn" { try await clerk.signIn.emailLink.sendLink(.case2(.init(emailAddressId: "idn_email"))) }
      else { try await clerk.signUp.verifications.sendEmailLink(.init()) }
      Issue.record("Expected email-link preparation to fail")
    } catch let error as CoreError {
      if storageFailure { #expect(error.code == "secure_storage_locked") }
      else { #expect(error.errors.first?.code == "prepare_rejected") }
    }
    #expect(host.prepares == (storageFailure ? 0 : 1))
    if storageFailure { #expect(host.base.authRecord == nil) }
    else { #expect(host.base.authRecord == host.savedRecord) }
    #expect(clerk.session == nil)
  }
}

@MainActor private final class EmailLinkFailureCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let kind: String
  let storageFailure: Bool
  var supported: [String] {
    base.supported
  }

  var prepares = 0
  var savedRecord: String?

  init(kind: String, storageFailure: Bool) throws {
    self.kind = kind
    self.storageFailure = storageFailure
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    var client = try base.fixtures["client"]!.object()
    var signIn = try base.fixtures["signIn"]!.object()
    signIn["supported_first_factors"] = .array([.object(["strategy": .string("email_link"), "email_address_id": .string("idn_email"), "safe_identifier": .string("test@example.com")])])
    var signUp = try base.fixtures["signUp"]!.object()
    signUp["email_address"] = .string("test@example.com")
    client["sign_in"] = .object(signIn)
    client["sign_up"] = .object(signUp)
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if capability == "authStorage.write", storageFailure { throw CoreError(code: "secure_storage_locked") }
    if capability == "http" {
      let path = try arguments.object()["url"]!.url().path
      if path.hasSuffix("/prepare_first_factor") || path.hasSuffix("/prepare_verification") {
        prepares += 1
        savedRecord = try #require(base.authRecord)
        let saved = try JSONDecoder().decode(JSONValue.self, from: Data(savedRecord!.utf8)).object()
        #expect(saved["kind"] == .string(kind))
        #expect(saved["flowId"] == .string(kind == "signIn" ? "sia_native" : "sua_native"))
        #expect(try saved["codeVerifier"]?.string().count == 43)
        return .object(["status": .number(422), "headers": .object([:]), "body": .string(#"{"errors":[{"code":"prepare_rejected","message":"Preparation rejected"}]}"#)])
      }
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
