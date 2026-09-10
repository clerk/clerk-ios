@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["clear-null", "clear-empty", "image", "metadata", "totp"])
  func userResourcesPreserveProfileAndEnrollmentState(scenario: String) async throws {
    let host = try UserResourceCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    switch scenario {
    case "clear-null", "clear-empty":
      #expect(user.fullName == "Original Name")
      let value: Field<String> = scenario == "clear-null" ? .null : .value("")
      let updated = try await user.update(.init(firstName: value, lastName: value))
      #expect(updated === user)
      #expect(user.firstName == nil && user.lastName == nil && user.fullName == nil)
      #expect(try host.body(0) == ["first_name": "", "last_name": ""])
    case "image":
      let image = try await user.setProfileImage(.init(file: nil))
      #expect(image.id == "img_profile")
      #expect(image.name == nil && image.publicUrl == nil)
      #expect(!user.hasImage && user.imageUrl == "")
      #expect(try host.effectiveMethod(0) == "DELETE")
    case "metadata":
      let updated = try await user.update(.init(firstName: .value("John"), unsafeMetadata: UserResourceCapabilities.desiredMetadata))
      #expect(updated === user)
      #expect(user.firstName == "John")
      #expect(user.unsafeMetadata == UserResourceCapabilities.desiredMetadata)
      #expect(host.requests.count == 2)
      #expect(try host.body(0) == ["first_name": "John"])
      let patchText = try #require(host.body(1)["unsafe_metadata"])
      let patch = try JSONDecoder().decode(JSONValue.self, from: Data(patchText.utf8))
      #expect(patch == .object(["token": .string("new-value"), "serverOnly": .null, "nested": .object(["added": .string("new"), "remove": .null])]))
    default:
      let enrollment = try await user.createTOTP()
      #expect(enrollment.id == "totp_profile" && enrollment.secret == "fixture_totp_secret" && !enrollment.verified)
      #expect(enrollment.uri == "otpauth://totp/fixture?secret=fixture_totp_secret")
      do {
        _ = try await user.verifyTOTP(.init(code: "wrong"))
        Issue.record("Expected invalid verification code")
      } catch let error as CoreError { #expect(error.errors.first?.code == "form_code_incorrect") }
      #expect(!user.totpEnabled)
      let verified = try await user.verifyTOTP(.init(code: "123456"))
      #expect(verified.verified && verified.secret == nil)
      #expect(verified.backupCodes == ["fixture_backup_one", "fixture_backup_two"])
      #expect(user.totpEnabled && user.twoFactorEnabled)
      let backup = try await user.createBackupCode()
      #expect(backup.codes == ["fixture_backup_one", "fixture_backup_two"])
      #expect(user.backupCodeEnabled)
      let removed = try await user.disableTOTP()
      #expect(removed.id == "totp_profile" && removed.deleted)
      #expect(!user.totpEnabled)
      #expect(try host.body(2) == ["code": "123456"])
      #expect(try host.effectiveMethod(4) == "DELETE")
    }
    for request in host.requests {
      let url = try #require(request.object()["url"]).url()
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      #expect(query.contains { $0.name == "_clerk_session_id" && $0.value == "sess_native" })
    }
  }
}

@MainActor private final class UserResourceCapabilities: NativeCapabilities {
  static let desiredMetadata: [String: JSONValue] = ["token": .string("new-value"), "nested": .object(["keep": .string("same"), "added": .string("new")])]
  let base: FixtureCapabilities
  let scenario: String
  var requests: [JSONValue] = []
  var user: [String: JSONValue]
  var client: [String: JSONValue]
  var supported: [String] {
    base.supported
  }

  init(scenario: String) throws {
    self.scenario = scenario
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(client["sessions"]).array()[0].object()
    user = try #require(session["user"]).object()
    user["first_name"] = .string("Original")
    user["last_name"] = .string("Name")
    user["has_image"] = .bool(true)
    user["image_url"] = .string("https://images.example/old.png")
    user["unsafe_metadata"] = .object(["staleLocal": .bool(true)])
    user["totp_enabled"] = .bool(false)
    user["two_factor_enabled"] = .bool(false)
    user["backup_code_enabled"] = .bool(false)
    session["user"] = .object(user)
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func body(_ index: Int) throws -> [String: String] {
    let value = try requests[index].object()["body"]
    guard case let .string(text) = value else { return [:] }
    var components = URLComponents()
    components.percentEncodedQuery = text.replacingOccurrences(of: "+", with: "%20")
    return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
  }

  func effectiveMethod(_ index: Int) throws -> String {
    let args = try requests[index].object()
    let url = try #require(args["url"]).url()
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return try query.first { $0.name == "_method" }?.value ?? #require(args["method"]).string()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try #require(args["url"]).url()
    guard url.path.hasPrefix("/v1/me") else { return try await base.perform(capability, arguments: arguments) }
    requests.append(arguments)
    var payload: JSONValue
    var failed = false
    switch scenario {
    case "clear-null", "clear-empty":
      user["first_name"] = scenario == "clear-null" ? .null : .string("")
      user["last_name"] = user["first_name"]
      payload = .object(user)
    case "image":
      user["has_image"] = .bool(false)
      user["image_url"] = .string("")
      payload = .object(["object": .string("image"), "id": .string("img_profile"), "deleted": .bool(true)])
    case "metadata":
      user["first_name"] = .string("John")
      user["unsafe_metadata"] = url.path.hasSuffix("/metadata") ? .object(Self.desiredMetadata) : .object(["token": .string("old-value"), "serverOnly": .bool(true), "nested": .object(["keep": .string("same"), "remove": .string("old")])])
      payload = .object(user)
    default:
      var totp: [String: JSONValue] = ["object": .string("totp"), "id": .string("totp_profile"), "secret": .string("fixture_totp_secret"), "uri": .string("otpauth://totp/fixture?secret=fixture_totp_secret"), "verified": .bool(false), "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000)]
      let codes: JSONValue = .array([.string("fixture_backup_one"), .string("fixture_backup_two")])
      if url.path.hasSuffix("/attempt_verification") {
        if try body(requests.count - 1)["code"] == "wrong" {
          failed = true
          payload = .object(["errors": .array([.object(["code": .string("form_code_incorrect"), "message": .string("Incorrect code")])])])
        } else {
          totp.removeValue(forKey: "secret")
          totp.removeValue(forKey: "uri")
          totp["verified"] = .bool(true)
          totp["backup_codes"] = codes
          user["totp_enabled"] = .bool(true)
          user["two_factor_enabled"] = .bool(true)
          payload = .object(totp)
        }
      } else if try effectiveMethod(requests.count - 1) == "DELETE" {
        user["totp_enabled"] = .bool(false)
        user["two_factor_enabled"] = .bool(false)
        payload = .object(["object": .string("totp"), "id": .string("totp_profile"), "deleted": .bool(true)])
      } else if url.path.contains("/backup_codes") {
        user["backup_code_enabled"] = .bool(true)
        payload = .object(["object": .string("backup_code"), "id": .string("bc_profile"), "codes": codes, "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000)])
      } else { payload = .object(totp) }
    }
    var document: [String: JSONValue] = failed ? try payload.object() : ["response": payload]
    if !failed, scenario == "image" || scenario == "totp" {
      var session = try #require(client["sessions"]).array()[0].object()
      session["user"] = .object(user)
      client["sessions"] = .array([.object(session)])
      document["client"] = .object(client)
      base.clientResponse = .object(client)
    }
    return try .object(["status": .number(failed ? 422 : 200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(JSONValue.object(document)), as: UTF8.self))])
  }
}
