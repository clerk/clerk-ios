@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["enroll", "forget", "corrupt", "same-id", "revoke-read", "saved-read", "list", "lost-session"])
  func biometricMetadataPreservesUnrelatedCredentials(scenario: String) async throws {
    let host = try BiometricMetadataCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    switch scenario {
    case "corrupt":
      do {
        _ = try await clerk.biometricCredentials.enroll()
        Issue.record("Unreadable metadata must not be overwritten")
      } catch let error as CoreError { #expect(error.code == "invalid_biometric_metadata") }
      #expect(host.base.biometricRecords == "not-json")
      #expect(host.writes == 0 && host.base.biometricSignCount == 0)
    case "forget":
      #expect(try await clerk.biometricCredentials.forgetLocalCredentials(.init(userId: "user_native")) == 1)
      #expect(try host.records() == [host.other, host.malformedOwn])
      #expect(host.deleted == ["key_old"])
    case "revoke-read":
      let revoked = try await clerk.biometricCredentials.revoke(.init(id: "td_old"))
      #expect(revoked.id == "td_old" && revoked.status == .case2("revoked"))
      #expect(host.writes == 0 && host.deleted.isEmpty)
    case "lost-session":
      do {
        _ = try await clerk.biometricCredentials.enroll()
        Issue.record("Enrollment must reject a lost initiating session")
      } catch let error as CoreError { #expect(error.code == "stale_authentication_attempt") }
      #expect(clerk.session == nil)
      #expect(host.deleted == ["tdlk_native"])
      #expect(try host.records().count == 3)
      #expect(host.requests.contains { request in
        guard let url = try? request["url"]?.url() else { return false }
        return url.path.hasSuffix("/td_native") && url.query?.contains("_method=DELETE") == true
      })
    case "list":
      let credentials = try await clerk.biometricCredentials.list()
      let value = try #require(credentials.first)
      #expect(value.id == "td_old" && value.object == "trusted_device")
      #expect(value.platform == .case1("ios") && value.algorithm == .case1("ES256"))
      #expect(value.name == "Test device" && value.appIdentifier == "com.example.native")
      #expect(value.createdAt == Date(timeIntervalSince1970: 1_710_000_000))
      #expect(value.updatedAt == Date(timeIntervalSince1970: 1_710_000_001))
      #expect(value.lastUsedAt == Date(timeIntervalSince1970: 1_710_000_002) && value.revokedAt == nil)
    default:
      let enrolled = try await clerk.biometricCredentials.enroll(.init(identifierHint: " TEST@example.com "))
      #expect(enrolled.id == "td_native")
      let records = try host.records()
      #expect(records.contains(host.other) && records.contains(host.malformedOwn))
      #expect(records.contains { (try? $0.object()["localKeyId"]) == .string("tdlk_native") })
      #expect(!host.deleted.contains("tdlk_native"))
      if scenario == "saved-read" {
        #expect(host.deleted.isEmpty)
        #expect(records.count == 4)
      } else {
        #expect(host.deleted == ["key_old"])
        #expect(records.count == 3)
      }
    }
    for request in host.requests {
      let url = try #require(request["url"]).url()
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      #expect(query.contains { $0.name == "_clerk_session_id" && $0.value == "sess_native" })
    }
  }
}

@MainActor private final class BiometricMetadataCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let scenario: String
  let other: JSONValue
  let malformedOwn: JSONValue
  var supported: [String] {
    base.supported
  }

  var deleted: [String] = []
  var requests: [[String: JSONValue]] = []
  var writes = 0

  init(scenario: String) throws {
    self.scenario = scenario
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    other = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"id":"other_legacy","localKeyId":"other_key","appIdentifier":"com.example.other","futureField":{"nested":["keep",null]}}"#.utf8))
    malformedOwn = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"id":"own_legacy","localKeyId":"own_key","appIdentifier":"com.example.native"}"#.utf8))
    let own: JSONValue = .object([
      "id": .string(scenario == "same-id" ? "td_native" : "td_old"), "localKeyId": .string("key_old"),
      "userId": .string("user_native"), "appIdentifier": .string("com.example.native"),
      "policy": .string("biometry_current_set"), "createdAt": .number(1_710_000_000_000), "updatedAt": .number(1_710_000_001_000),
    ])
    base.biometricRecords = try scenario == "corrupt" ? "not-json" : String(decoding: JSONEncoder().encode(JSONValue.array([own, other, malformedOwn])), as: UTF8.self)
  }

  func records() throws -> [JSONValue] {
    try JSONDecoder().decode(JSONValue.self, from: Data(#require(base.biometricRecords).utf8)).array()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "biometrics.storage.read", args["key"] == .string("credentials"),
       scenario == "revoke-read" || (scenario == "saved-read" && writes > 0)
    {
      throw CoreError(code: "secure_storage_locked")
    }
    if capability == "biometrics.storage.write", args["key"] == .string("credentials") { writes += 1 }
    if capability == "biometrics.deleteKey" { try deleted.append(#require(args["localKeyId"]).string()) }
    if capability == "http" {
      let url = try #require(args["url"]).url()
      if url.path.contains("/biometric_credentials") {
        requests.append(args)
        if scenario == "lost-session", url.path.hasSuffix("/attempt") {
          var response = try await base.perform(capability, arguments: arguments).object()
          let bodyText = try #require(response["body"]).string()
          var body = try JSONDecoder().decode(JSONValue.self, from: Data(bodyText.utf8)).object()
          body["client"] = base.fixtures["client"]
          response["body"] = try .string(String(decoding: JSONEncoder().encode(JSONValue.object(body)), as: UTF8.self))
          return .object(response)
        }
        if url.path.hasSuffix("/td_old") || url.path.hasSuffix("/td_native") || url.path.hasSuffix("/biometric_credentials") {
          let credential: JSONValue = .object([
            "id": .string("td_old"), "object": .string("trusted_device"), "platform": .string("ios"),
            "app_identifier": .string("com.example.native"), "name": .string("Test device"), "algorithm": .string("ES256"),
            "status": .string(url.path.hasSuffix("/td_old") ? "revoked" : "active"),
            "created_at": .number(1_710_000_000_000), "updated_at": .number(1_710_000_001_000),
            "last_used_at": .number(1_710_000_002_000), "revoked_at": .null,
          ])
          let body: JSONValue = .object(["response": url.path.hasSuffix("/td_old") ? credential : .array([credential])])
          return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
        }
      }
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
