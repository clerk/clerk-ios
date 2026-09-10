@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: [false, true])
  func emptyClientRefreshPreservesAcceptedIdentity(newerSessionResponse: Bool) async throws {
    let host = try EmptyClientCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { host.release(); clerk.close() }
    let runtime = try clerk.context.requireRuntime()
    let session = try #require(clerk.session)
    let credential = host.base.credential
    let clientId = clerk.clientId
    host.holdClient = true
    runtime.setApplicationActive(false)
    runtime.setApplicationActive(true)
    try await host.wait { host.waiting }
    if newerSessionResponse { _ = try await session.reload() }
    try await Task.sleep(for: .milliseconds(20))
    let revision = runtime.revision
    host.release()
    try await host.wait { runtime.revision > revision || runtime.lastLifecycleError != nil }
    #expect(runtime.lastLifecycleError == nil)
    #expect(clerk.clientId == clientId)
    #expect(clerk.session === session)
    #expect(clerk.session?.status.rawValue == (newerSessionResponse ? "pending" : "active"))
    if newerSessionResponse { #expect(clerk.session?.currentTask?.key.rawValue == "choose-organization") }
    #expect(host.base.credential == credential)
  }
}

@MainActor private final class EmptyClientCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var holdClient = false
  var waiting: Bool {
    continuation != nil
  }

  private var continuation: CheckedContinuation<Void, Never>?

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    var client = try base.fixtures["authenticatedClient"]!.object()
    base.clientResponse = .object(client)
    var session = try client["sessions"]!.array()[0].object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string("choose-organization")])])
    client["sessions"] = .array([.object(session)])
    base.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
  }

  func wait(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition() {
      guard ContinuousClock.now < deadline else { throw CoreError(code: "empty_client_test_timeout") }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  func release() {
    continuation?.resume()
    continuation = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if try capability == "http" && holdClient && arguments.object()["url"]?.url().path.hasSuffix("/client") == true {
      #expect(try arguments.object()["method"]?.string() == "GET")
      await withCheckedContinuation { continuation = $0 }
      return .object(["status": .number(200), "headers": .object([:]), "body": .string("{\"response\":null}")])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
