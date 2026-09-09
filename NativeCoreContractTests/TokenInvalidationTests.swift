@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

/// The lifecycle tests post process-wide notifications. Share their serialized suite
/// so a simulated background event cannot race this deliberately foregrounded core.
extension PackagedCoreTests {
  @Test(arguments: [false, true])
  func clearCacheRejectsAProactiveRefresh(replacement: Bool) async throws {
    let host = try TokenInvalidationCapabilities(proactive: true)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { host.release(1); clerk.close() }
    try clerk.context.requireRuntime().setApplicationActive(true)
    try await Task.sleep(for: .milliseconds(30))
    let session = try #require(clerk.session)
    #expect(try await session.getToken(.init(template: "firebase")) == host.tokens[0])
    try await host.waitForRequests(2)
    try await session.clearCache()
    if replacement { #expect(try await session.getToken(.init(template: "firebase")) == host.tokens[2]) }
    host.release(1)
    // Let the background reply finish its engine jobs before the next public cache read.
    try await Task.sleep(for: .milliseconds(20))
    #expect(try await session.getToken(.init(template: "firebase")) == host.tokens[2])
    #expect(host.requests == 3)
    #expect(clerk.session?.id == session.id)
  }

  @Test(arguments: [false, true])
  func clearCacheSeparatesPendingTokenRequests(oldReplyFirst: Bool) async throws {
    let host = try TokenInvalidationCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { host.release(0); host.release(1); clerk.close() }
    let session = try #require(clerk.session)
    let first = Task { try await session.getToken(.init(template: "firebase")) }
    try await host.waitForRequests(1)
    try await session.clearCache()
    let second = Task { try await session.getToken(.init(template: "firebase")) }
    try await host.waitForRequests(2)
    if oldReplyFirst {
      host.release(0)
      #expect(try await first.value == host.tokens[0])
      host.release(1)
      #expect(try await second.value == host.tokens[1])
    } else {
      host.release(1)
      #expect(try await second.value == host.tokens[1])
      host.release(0)
      #expect(try await first.value == host.tokens[0])
    }
    #expect(try await session.getToken(.init(template: "firebase")) == host.tokens[1])
    #expect(host.requests == 2)
    #expect(clerk.session?.id == session.id)
  }
}

@MainActor private final class TokenInvalidationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let tokens: [String]
  private let proactive: Bool
  private var fired = false
  private(set) var requests = 0
  private var continuations: [CheckedContinuation<Void, Never>?] = [nil, nil]

  init(proactive: Bool = false) throws {
    self.proactive = proactive
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = try #require(base.fixtures["authenticatedClient"])
    let now = Int(Date().timeIntervalSince1970)
    func encoded(_ value: String) -> String {
      Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    tokens = (proactive ? [50, 200, 100] : [200, 100]).map { origin in
      let ttl = proactive && origin == 50 ? 60 : 3600
      return encoded("{\"alg\":\"none\",\"typ\":\"JWT\",\"oiat\":\(origin)}") + "." + encoded("{\"sid\":\"sess_native\",\"iat\":\(now),\"exp\":\(now + ttl)}") + ".fixture"
    }
  }

  func waitForRequests(_ count: Int) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while requests < count {
      guard ContinuousClock.now < deadline else { throw CoreError(code: "token_test_timeout") }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func release(_ index: Int) {
    continuations[index]?.resume()
    continuations[index] = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if proactive && !fired && capability == "timer" {
      let delay = try (arguments.object()["milliseconds"] ?? .number(0)).number()
      if delay >= 42000, delay <= 44000 { fired = true; return .null }
    }
    if try capability != "http" || arguments.object()["url"]?.url().path.hasSuffix("/sessions/sess_native/tokens/firebase") != true {
      return try await base.perform(capability, arguments: arguments)
    }
    let index = requests
    requests += 1
    guard index < tokens.count else { throw CoreError(code: "unexpected_token_fetch") }
    if !proactive || index == 1 { await withCheckedContinuation { continuations[index] = $0 } }
    let body = JSONValue.object(["object": .string("token"), "jwt": .string(tokens[index])])
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
