import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["current", "other", "rejected"])
  func generatedRevocationReconcilesSessionSelection(scenario: String) async throws {
    let host = try RevocationCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let selected = try #require(clerk.session)
    let user = try #require(clerk.user)
    let listed = try #require(await user.getSessions().first)
    #expect(listed.id == host.targetId)
    #expect(listed.latestActivity.browserName == "Safari" && listed.latestActivity.isMobile == true)
    if scenario == "rejected" {
      do { _ = try await listed.revoke(); Issue.record("Expected rejection") }
      catch let error as CoreError { #expect(error.status == 403 && error.errors.first?.code == "session_revoke_denied") }
      #expect(listed.status == "active")
    } else {
      let result = try await listed.revoke()
      #expect(result.status == "revoked" && result.id == host.targetId)
    }
    #expect(host.revocations == 1)
    if scenario == "current" {
      #expect(clerk.session == nil && selected.isInvalidated)
      do { _ = try await selected.getToken(); Issue.record("Expected stale resource") }
      catch let error as CoreError { #expect(error.code == "stale_resource") }
    } else { #expect(clerk.session?.id == selected.id) }
  }

  @Test(arguments: ["setup-mfa", "reset-password", "another-task"])
  func generatedPendingTaskPreservesKnownAndFutureKeys(key: String) async throws {
    let host = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clientValue = try #require(host.fixtures["authenticatedClient"])
    var client = try clientValue.object()
    let sessionsValue = try #require(client["sessions"])
    var session = try sessionsValue.array()[0].object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string(key)])])
    client["sessions"] = .array([.object(session)])
    host.clientResponse = .object(client)
    let publishableKey = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: publishableKey, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let pending = try #require(clerk.session)
    #expect(pending.status == .pending)
    let expected: SessionTaskKey = key == "setup-mfa" ? .setupMfa : key == "reset-password" ? .resetPassword : .unrecognized(key)
    #expect(pending.tasks?.map(\.key) == [expected])
    #expect(pending.currentTask?.key == expected)
  }
}

@MainActor private final class RevocationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let scenario: String
  var targetId: String {
    scenario == "other" ? "sess_other" : "sess_native"
  }

  private(set) var revocations = 0
  init(scenario: String) throws {
    self.scenario = scenario
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let path = try args["url"]!.url().path
    guard path.hasSuffix("/me/sessions/active") || path.hasSuffix("/revoke") else { return try await base.perform(capability, arguments: arguments) }
    var client = try base.fixtures["authenticatedClient"]!.object()
    var session = try client["sessions"]!.array()[0].object()
    var listed = session
    listed["id"] = .string(targetId)
    listed["user"] = .null
    listed["latest_activity"] = .object(["id": .string("act_fixture"), "browser_name": .string("Safari"), "is_mobile": .bool(true)])
    let body: JSONValue
    if path.hasSuffix("/active") {
      #expect(args["method"] == .string("GET"))
      body = .array([.object(listed)])
    } else {
      revocations += 1
      #expect(path == "/v1/me/sessions/\(targetId)/revoke")
      #expect(args["method"] == .string("POST") && args["body"] == .string(""))
      if scenario == "rejected" {
        return .object(["status": .number(403), "headers": .object([:]), "body": .string("{\"errors\":[{\"code\":\"session_revoke_denied\",\"message\":\"Cannot revoke\"}]}")])
      }
      listed["status"] = .string("revoked")
      if scenario == "current" {
        session["status"] = .string("revoked")
        client["sessions"] = .array([.object(session)])
      }
      body = .object(["response": .object(listed), "client": .object(client)])
    }
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
