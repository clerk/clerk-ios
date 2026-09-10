@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: [false, true])
  func passkeyRegistrationAndManagement(cancelled: Bool) async throws {
    let host = try PasskeyRegistrationCapabilities(cancelled: cancelled)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    if cancelled {
      do { _ = try await user.createPasskey(); Issue.record("Expected cancellation") }
      catch let error as CoreError { #expect(error.code == "user_cancelled") }
      #expect(host.paths == ["/v1/me/passkeys"])
    } else {
      let passkey = try await user.createPasskey()
      #expect(passkey.id == "passkey_native")
      #expect(passkey.verification?.status?.rawValue == "verified")
      let updated = try await passkey.update(.init(name: .value("New Name")))
      #expect(updated === passkey)
      #expect(passkey.name == "New Name")
      let removed = try await passkey.delete()
      #expect(removed.id == passkey.id)
      #expect(removed.deleted)
      #expect(passkey.name == "New Name")
      #expect(host.paths == ["/v1/me/passkeys", "/v1/me/passkeys/passkey_native/attempt_verification", "/v1/me/passkeys/passkey_native", "/v1/me/passkeys/passkey_native"])
    }
    #expect(host.presentations == 1)
  }
}

@MainActor private final class PasskeyRegistrationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let cancelled: Bool
  var supported: [String] {
    base.supported
  }

  var paths: [String] = []
  var presentations = 0
  var passkey: [String: JSONValue]
  static let options = #"{"challenge":"Y2hhbGxlbmdl","rp":{"id":"example.com","name":"Example"},"user":{"id":"dXNlcl9uYXRpdmU","name":"test@example.com","displayName":"Test User"},"pubKeyCredParams":[{"type":"public-key","alg":-7}],"authenticatorSelection":{"authenticatorAttachment":"platform","userVerification":"required"},"excludeCredentials":[{"type":"public-key","id":"b2xkX2NyZWRlbnRpYWw"}]}"#
  static let credential = #"{"id":"Y3JlZGVudGlhbA","type":"public-key","rawId":"Y3JlZGVudGlhbA","authenticatorAttachment":"platform","response":{"clientDataJSON":"e30","attestationObject":"YXR0ZXN0YXRpb24","transports":["internal"]}}"#

  init(cancelled: Bool) throws {
    self.cancelled = cancelled
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    passkey = ["object": .string("passkey"), "id": .string("passkey_native"), "name": .null, "last_used_at": .null, "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000), "verification": .object(["status": .string("unverified"), "strategy": .string("passkey"), "nonce": .string(Self.options), "attempts": .null, "expire_at": .null, "error": .null, "verified_at_client": .null])]
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "passkeys.create" {
      presentations += 1
      #expect(try args["rp"]?.object()["id"] == .string("example.com"))
      #expect(args["challenge"] == .object(["base64url": .string("Y2hhbGxlbmdl")]))
      #expect(try args["user"]?.object()["id"] == .object(["base64url": .string("dXNlcl9uYXRpdmU")]))
      if cancelled { throw CoreError(code: "user_cancelled") }
      return try JSONDecoder().decode(JSONValue.self, from: Data(Self.credential.utf8))
    }
    if capability == "http", let url = try args["url"]?.url(), url.path.contains("/passkeys") {
      paths.append(url.path)
      #expect(args["method"] == .string("POST"))
      let method = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "_method" }?.value
      let body: String = if case .string(let value) = args["body"] { value }
      else { "" }
      let fields = URLComponents(string: "https://fixture.test/?" + body.replacingOccurrences(of: "+", with: "%20"))?.queryItems ?? []
      func field(_ name: String) -> String? {
        fields.first { $0.name == name }?.value
      }
      var response: JSONValue
      if url.path.hasSuffix("/attempt_verification") {
        #expect(field("strategy") == "passkey")
        let submitted = try JSONDecoder().decode(JSONValue.self, from: Data(#require(field("public_key_credential")).utf8)).object()
        #expect(try submitted["response"]?.object()["attestationObject"] == .string("YXR0ZXN0YXRpb24"))
        var verification = try passkey["verification"]!.object()
        verification["status"] = .string("verified")
        passkey["verification"] = .object(verification)
        response = .object(passkey)
      } else if method == "PATCH" {
        #expect(field("name") == "New Name")
        passkey["name"] = .string("New Name")
        response = .object(passkey)
      } else if method == "DELETE" { response = .object(["object": .string("passkey"), "id": .string("passkey_native"), "deleted": .bool(true)]) }
      else { response = .object(passkey) }
      let payload = try String(data: JSONEncoder().encode(JSONValue.object(["response": response])), encoding: .utf8)!
      return .object(["status": .number(200), "headers": .object([:]), "body": .string(payload)])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
