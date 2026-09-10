@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test func unauthorizedClientRecoveryTerminatesAndAllowsAnotherRequest() async throws {
    let host = try UnauthorizedRecoveryCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let session = try #require(clerk.session)
    do {
      _ = try await session.reload()
      Issue.record("Expected the unauthorized response")
    } catch let error as CoreError {
      #expect(error.status == 401)
      #expect(error.errors.first?.code == "authentication_invalid")
    }
    #expect(host.clientReads == 2)
    #expect(clerk.session === session)
    #expect(session.status.rawValue == "active")
    guard host.clientReads == 2 else { return }
    host.rejecting = false
    let returned = try await session.reload()
    #expect(returned === session)
  }
}

@MainActor private final class UnauthorizedRecoveryCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var clientReads = 0
  var rejecting = true

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    base.sessionReloadResponse = try .object(["response": #require(base.fixtures["session"])])
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let path = try #require(arguments.object()["url"]).url().path
    if path == "/v1/client" { clientReads += 1 }
    if !rejecting || (path == "/v1/client" && clientReads == 1) || (path != "/v1/client" && path != "/v1/client/sessions/sess_native") {
      return try await base.perform(capability, arguments: arguments)
    }
    return .object([
      "status": .number(clientReads >= 4 ? 403 : 401),
      "headers": .object([:]),
      "body": .string(#"{"errors":[{"code":"authentication_invalid","message":"Authentication invalid"}]}"#),
    ])
  }
}

extension PackagedCoreTests {
  @Test func transientNetworkFailureRetriesAndCompletes() async throws {
    let host = try RetryIdentityCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { host.releaseRequest(); clerk.close() }
    let session = try #require(clerk.session)
    let pending = Task { try await session.reload() }
    await host.waitForRequest()
    host.releaseRequest()
    let returned = try await pending.value
    #expect(returned === session)
    #expect(host.attempts == 2)
    #expect(clerk.session === session)
  }

  @Test(arguments: [false, true])
  func obsoleteCredentialDoesNotReachRetry(signOut: Bool) async throws {
    let host = try RetryIdentityCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { host.releaseRequest(); clerk.close() }
    let session = try #require(clerk.session)
    let pending = Task { try await session.reload() }
    await host.waitForRequest()
    if signOut { try await clerk.signOut() }
    else { _ = try await #require(clerk.user).reload() }
    host.releaseRequest()
    do {
      _ = try await pending.value
      Issue.record("Expected the obsolete request to fail")
    } catch is CoreError {}
    #expect(host.attempts == 1)
    if signOut { #expect(clerk.session == nil) }
    else {
      #expect(clerk.session === session)
      #expect(host.base.credential == "rotated-client-credential")
    }
  }
}

@MainActor private final class RetryIdentityCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var attempts = 0
  private var started: CheckedContinuation<Void, Never>?
  private var release: CheckedContinuation<Void, Never>?

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    base.sessionReloadResponse = try .object(["response": #require(base.fixtures["session"])])
  }

  func waitForRequest() async {
    if attempts == 0 { await withCheckedContinuation { started = $0 } }
  }

  func releaseRequest() {
    release?.resume()
    release = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let path = try #require(arguments.object()["url"]).url().path
    if path == "/v1/client/sessions/sess_native" {
      attempts += 1
      if attempts == 1 {
        await withCheckedContinuation {
          release = $0
          started?.resume()
          started = nil
        }
        throw CoreError(code: "network_unavailable")
      }
    }
    if path == "/v1/me" {
      let user = try #require(base.fixtures["session"]?.object()["user"])
      let body = try JSONEncoder().encode(JSONValue.object(["response": user]))
      return .object([
        "status": .number(200),
        "headers": .object(["authorization": .string("rotated-client-credential")]),
        "body": .string(String(decoding: body, as: UTF8.self)),
      ])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
