import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: [[0], [1], [0, 1]])
  func coalescedTokenCallsCancelIndependently(cancelled: [Int]) async throws {
    try await checkTokenCancellation(cancelled: cancelled, failRequest: false)
  }

  @Test(arguments: [0, 1])
  func coalescedTokenFailurePermitsRecovery(cancelled: Int) async throws {
    try await checkTokenCancellation(cancelled: [cancelled], failRequest: true)
  }

  private func checkTokenCancellation(cancelled: [Int], failRequest: Bool) async throws {
    let host = try TokenCancellationCapabilities(failRequest: failRequest)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { host.release(); clerk.close() }
    let session = try #require(clerk.session)
    let first = Task { try await session.getToken(.init(template: "firebase")) }
    try await host.waitForRequest()
    let second = Task { try await session.getToken(.init(template: "firebase")) }
    // Allow the second generated invocation to join the pending source request.
    try await Task.sleep(for: .milliseconds(20))
    #expect(host.requests == 1)
    let calls = [first, second]
    for index in cancelled {
      calls[index].cancel()
      await #expect(throws: CancellationError.self) { try await calls[index].value }
    }
    host.release()
    for index in [0, 1] where !cancelled.contains(index) {
      if failRequest {
        do { _ = try await calls[index].value; Issue.record("Expected the shared token error") }
        catch let error as CoreError {
          #expect(error.status == 403)
          #expect(error.errors.first?.code == "token_denied")
        }
      } else { #expect(try await calls[index].value == host.token) }
    }
    try await Task.sleep(for: .milliseconds(20))
    #expect(try await session.getToken(.init(template: "firebase")) == host.token)
    #expect(host.requests == (failRequest ? 2 : 1))
    #expect(clerk.session?.id == session.id)
  }
}

@MainActor private final class TokenCancellationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let token: String
  private let failRequest: Bool
  private(set) var requests = 0
  private var continuation: CheckedContinuation<Void, Never>?

  init(failRequest: Bool) throws {
    self.failRequest = failRequest
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = try #require(base.fixtures["authenticatedClient"])
    let now = Int(Date().timeIntervalSince1970)
    func encoded(_ value: String) -> String {
      Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    token = encoded("{\"alg\":\"none\",\"typ\":\"JWT\"}") + "." + encoded("{\"sid\":\"sess_native\",\"iat\":\(now),\"exp\":\(now + 3600)}") + ".fixture"
  }

  func waitForRequest() async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while requests == 0 {
      guard ContinuousClock.now < deadline else { throw CoreError(code: "token_test_timeout") }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func release() {
    continuation?.resume(); continuation = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if try capability != "http" || arguments.object()["url"]?.url().path.hasSuffix("/sessions/sess_native/tokens/firebase") != true {
      return try await base.perform(capability, arguments: arguments)
    }
    requests += 1
    let first = requests == 1
    if first { await withCheckedContinuation { continuation = $0 } }
    let failed = first && failRequest
    let body = failed ? JSONValue.object(["errors": .array([.object(["code": .string("token_denied"), "message": .string("Token denied")])])]) : .object(["object": .string("token"), "jwt": .string(token)])
    return try .object(["status": .number(failed ? 403 : 200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
