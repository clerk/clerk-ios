import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["initial", "clear", "mintTie", "stale", "fresh", "tie", "expired"])
  func tokenSnapshotsFollowCanonicalCachePolicy(scenario: String) async throws {
    let host = try TokenSnapshotCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let session = try #require(clerk.session)
    #expect(try await session.getToken() == host.initial)
    #expect(host.previousTokens.isEmpty)
    if scenario == "initial" { return }
    if scenario == "clear" {
      try await session.clearCache()
      #expect(try await session.getToken() == host.minted)
      #expect(host.previousTokens == [host.initial])
      return
    }
    #expect(try await session.getToken(.init(skipCache: true)) == host.minted)
    #expect(host.previousTokens == [host.initial])
    if scenario == "mintTie" {
      #expect(try await session.getToken() == host.minted)
      #expect(host.previousTokens == [host.initial])
      return
    }
    _ = try await session.reload()
    #expect(clerk.session?.handle == session.handle)
    if scenario == "expired" {
      #expect(try await session.getToken() == host.final)
      #expect(host.previousTokens == [host.initial, host.minted])
    } else {
      #expect(try await session.getToken() == (scenario == "stale" ? host.minted : host.snapshot))
      #expect(host.previousTokens == [host.initial])
    }
  }
}

@MainActor private final class TokenSnapshotCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let initial: String
  let minted: String
  let snapshot: String
  let final: String
  private(set) var previousTokens: [String?] = []

  init(scenario: String) throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    let now = Int(Date().timeIntervalSince1970)
    func token(_ origin: Int, _ name: String, expired: Bool = false) -> String {
      func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
      }
      return encode("{\"alg\":\"none\",\"typ\":\"JWT\",\"oiat\":\(origin)}") + "." + encode("{\"sid\":\"sess_native\",\"iat\":\(now - 20),\"exp\":\(now + (expired ? -10 : 3600))}") + "." + name
    }
    initial = token(100, "initial")
    minted = token(scenario == "mintTie" ? 100 : 200, "minted", expired: scenario == "expired")
    snapshot = token(scenario == "fresh" ? 300 : scenario == "tie" ? 200 : 50, "snapshot", expired: scenario == "expired")
    final = token(400, "final")
    var client = try base.fixtures["authenticatedClient"]!.object()
    var session = try client["sessions"]!.array()[0].object()
    session["last_active_token"] = .object(["object": .string("token"), "jwt": .string(initial)])
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
    session["last_active_token"] = .object(["object": .string("token"), "jwt": .string(snapshot)])
    client["sessions"] = .array([.object(session)])
    base.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
    var environment = try base.fixtures["environment"]!.object()
    var auth = try environment["auth_config"]!.object()
    auth["session_minter"] = .bool(true)
    environment["auth_config"] = .object(auth)
    base.environmentResponse = .object(environment)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if try capability != "http" || arguments.object()["url"]?.url().path.hasSuffix("/sessions/sess_native/tokens") != true {
      return try await base.perform(capability, arguments: arguments)
    }
    var components = URLComponents()
    components.percentEncodedQuery = try arguments.object()["body"]?.string()
    previousTokens.append(components.queryItems?.first(where: { $0.name == "token" })?.value)
    guard previousTokens.count <= 2 else { throw CoreError(code: "unexpected_token_fetch") }
    let body = JSONValue.object(["object": .string("token"), "jwt": .string(previousTokens.count == 1 ? minted : final)])
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
