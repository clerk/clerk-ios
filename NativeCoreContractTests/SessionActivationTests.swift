import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["org_next", "personal", "omitted"])
  func organizationActivationUsesAcceptedServerState(selection: String) async throws {
    let host = try ActivationCapabilities()
    let clerk = try await activationClerk(host)
    defer { clerk.close() }
    let params = selection == "omitted" ? MobileSetActiveParams() : MobileSetActiveParams(organization: selection == "personal" ? .null : .value(.case1(selection)))
    try await clerk.setActive(params)
    let expected = selection == "omitted" ? "org_previous" : selection == "personal" ? nil : selection
    #expect(clerk.session?.lastActiveOrganizationId == expected)
    #expect(clerk.organization?.id == expected)
    #expect(host.lastBody == ["active_organization_id": expected ?? "", "intent": selection == "omitted" ? "select_session" : "select_org"])
  }

  @Test func rejectedOrganizationActivationPreservesSelection() async throws {
    let host = try ActivationCapabilities()
    let clerk = try await activationClerk(host)
    defer { clerk.close() }
    do { try await clerk.setActive(.init(organization: .value(.case1("org_rejected")))); Issue.record("Expected rejection") }
    catch let error as CoreError { #expect(error.status == 403 && error.errors.first?.code == "not_a_member_in_organization") }
    #expect(clerk.session?.lastActiveOrganizationId == "org_previous")
    #expect(clerk.organization?.id == "org_previous")
  }

  @Test func rejectedPendingOrganizationCannotOverwriteNewerSelection() async throws {
    let host = try ActivationCapabilities(holdRejection: true)
    let clerk = try await activationClerk(host)
    defer { host.release(); clerk.close() }
    let rejected = Task { try await clerk.setActive(.init(organization: .value(.case1("org_rejected")))) }
    let deadline = ContinuousClock.now + .seconds(3)
    while !host.rejectionStarted {
      guard ContinuousClock.now < deadline else { throw CoreError(code: "activation_test_timeout") }
      try await Task.sleep(for: .milliseconds(5))
    }
    let session = try #require(clerk.session)
    _ = try await session.checkAuthorization(.case1(.init(role: "org:admin")))
    #expect(session.lastActiveOrganizationId == "org_previous")
    try await clerk.setActive(.init(organization: .value(.case1("org_next"))))
    host.release()
    do { try await rejected.value; Issue.record("Expected rejection") }
    catch let error as CoreError { #expect(error.status == 403) }
    #expect(clerk.session?.lastActiveOrganizationId == "org_next" && clerk.organization?.id == "org_next")
  }
}

@MainActor private func activationClerk(_ host: ActivationCapabilities) async throws -> Clerk {
  let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
  return try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!), capabilities: host)
}

@MainActor private final class ActivationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var client: [String: JSONValue]
  let token: JSONValue
  let holdRejection: Bool
  private var continuation: CheckedContinuation<Void, Never>?
  private(set) var rejectionStarted = false
  private(set) var lastBody: [String: String]?
  init(holdRejection: Bool = false) throws {
    self.holdRejection = holdRejection
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    client = try base.fixtures["authenticatedClient"]!.object()
    var session = try client["sessions"]!.array()[0].object()
    var user = try session["user"]!.object()
    user["organization_memberships"] = try .array(["org_previous", "org_rejected", "org_next"].map { id in
      let raw = """
      {"object":"organization_membership","id":"om_\(id)","role":"org:admin","role_name":"Admin","permissions":["org:read"],"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000,"organization":{"object":"organization","id":"\(id)","name":"\(id)","slug":"\(id)","image_url":"","has_image":false,"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000}}
      """
      return try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
    })
    session["user"] = .object(user)
    session["last_active_organization_id"] = .string("org_previous")
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
    let now = Int(Date().timeIntervalSince1970)
    func encoded(_ value: String) -> String {
      Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    token = .object(["object": .string("token"), "jwt": .string(encoded("{\"alg\":\"none\"}") + "." + encoded("{\"sid\":\"sess_native\",\"iat\":\(now),\"exp\":\(now + 3600)}") + ".fixture")])
  }

  func release() {
    continuation?.resume(); continuation = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let path = try args["url"]!.url().path
    let body: JSONValue
    if path.hasSuffix("/tokens") { body = token }
    else if path.hasSuffix("/touch") {
      var query = URLComponents(); query.percentEncodedQuery = try args["body"]!.string()
      lastBody = Dictionary(uniqueKeysWithValues: (query.queryItems ?? []).map { ($0.name, $0.value ?? "") })
      let requested = lastBody?["active_organization_id"] ?? ""
      if requested == "org_rejected" {
        rejectionStarted = true
        if holdRejection { await withCheckedContinuation { continuation = $0 } }
        return .object(["status": .number(403), "headers": .object([:]), "body": .string("{\"errors\":[{\"code\":\"not_a_member_in_organization\",\"message\":\"Unable to switch\"}]}")])
      }
      var session = try client["sessions"]!.array()[0].object()
      session["last_active_organization_id"] = requested.isEmpty ? .null : .string(requested)
      client["sessions"] = .array([.object(session)])
      base.clientResponse = .object(client)
      body = .object(["response": .object(session), "client": .object(client)])
    } else { return try await base.perform(capability, arguments: arguments) }
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
