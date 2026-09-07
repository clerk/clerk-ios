#if !os(watchOS)
import ClerkJSCore
@testable import ClerkKit
import ClerkSnapshots
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct WatchOperationTests {
  @Test
  func phoneExecutesSharedSignOutAndReturnsAuthoritativeState() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let clerk = Clerk.shared
    let coordinator = WatchConnectivityCoordinator(sync: WatchOperationTransport())
    let request = try request(for: clerk)
    let responseData = try JSONSerialization.data(withJSONObject: ["response": ["object": "client", "id": "client_fixture", "sessions": [], "last_active_session_id": NSNull()]])
    Mock(url: URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!, ignoreQuery: true, contentType: .json, statusCode: 200, data: [.delete: responseData]).register()
    let response = try await JSONDecoder().decode(WatchOperationResponse.self, from: coordinator.handleOperation(JSONEncoder().encode(request), for: clerk))
    #expect(response.id == request.id)
    #expect(response.message == nil)
    #expect(response.apiError == nil)
    #expect(clerk.session == nil)
    let state = try #require(response.state)
    let context = try #require(PropertyListSerialization.propertyList(from: state, format: nil) as? [String: Any])
    #expect(WatchSyncPayload(applicationContext: context)?.client?.lastActiveSessionId == nil)
    await host.dispose()
  }

  @Test(arguments: ["session", "client", "instance"])
  func phoneRejectsRequestsFromStaleCompanionIdentity(mismatch: String) async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let clerk = Clerk.shared
    let request = try WatchOperationRequest(
      id: UUID(), publishableKey: mismatch == "instance" ? "pk_other" : clerk.publishableKey,
      clientId: mismatch == "client" ? "old_client" : clerk.client?.id,
      sessionId: mismatch == "session" ? "old_session" : clerk.session?.id,
      invocation: JSONValue(encoding: ClerkJSInvocation(receiver: .clerk, method: "signOut", arguments: []))
    )
    let coordinator = WatchConnectivityCoordinator(sync: WatchOperationTransport())
    if mismatch == "instance" {
      await #expect(throws: Error.self) { try await coordinator.handleOperation(JSONEncoder().encode(request), for: clerk) }
    } else {
      let response = try await JSONDecoder().decode(WatchOperationResponse.self, from: coordinator.handleOperation(JSONEncoder().encode(request), for: clerk))
      #expect(response.message != nil)
      #expect(response.result == nil)
      #expect(response.state != nil)
    }
    #expect(clerk.session?.id == "sess_fixture")
    await host.dispose()
  }

  @Test
  func companionAppliesReplyBeforeSignOutReturns() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let clerk = Clerk.shared
    await Clerk.disposeEngine()
    let transport = WatchOperationTransport()
    var signedOut = try #require(clerk.client)
    signedOut.sessions = []
    signedOut.lastActiveSessionId = nil
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "fixture-client-jwt", version: .init(rawValue: 10)),
      clientUpdate: .snapshot(client: signedOut, serverFetchDate: Date(), version: .init(rawValue: 10)),
      environment: nil
    )
    let state = try PropertyListSerialization.data(fromPropertyList: payload.applicationContext, format: .binary, options: 0)
    transport.operation = { data in
      let request = try JSONDecoder().decode(WatchOperationRequest.self, from: data)
      #expect(request.clientId == "client_fixture")
      #expect(request.sessionId == "sess_fixture")
      return try JSONEncoder().encode(WatchOperationResponse(id: request.id, result: .null, apiError: nil, message: nil, state: state))
    }
    clerk.watchConnectivityCoordinator = WatchConnectivityCoordinator(sync: transport)
    Clerk.engineClient = WatchOperationEngine(kit: clerk)
    try await clerk.auth.signOut()
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func companionRejectsUnrelatedReplyAndUnavailablePhone() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let clerk = Clerk.shared
    await Clerk.disposeEngine()
    let transport = WatchOperationTransport()
    clerk.watchConnectivityCoordinator = WatchConnectivityCoordinator(sync: transport)
    let engine = WatchOperationEngine(kit: clerk)
    let invocation = ClerkJSInvocation(receiver: .clerk, method: "signOut", arguments: [])
    await #expect(throws: Error.self) { try await engine.invoke(invocation) }
    transport.operation = { _ in
      try JSONEncoder().encode(WatchOperationResponse(id: UUID(), result: .null, apiError: nil, message: nil, state: nil))
    }
    await #expect(throws: Error.self) { try await engine.invoke(invocation) }
    #expect(clerk.session?.id == "sess_fixture")
    await host.dispose()
  }

  @Test
  func replacingCompanionRuntimeCancelsItsPendingRequest() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let clerk = Clerk.shared
    await Clerk.disposeEngine()
    let transport = WatchOperationTransport()
    transport.operation = { _ in
      try await Task.sleep(for: .seconds(60))
      return Data()
    }
    clerk.watchConnectivityCoordinator = WatchConnectivityCoordinator(sync: transport)
    let engine = WatchOperationEngine(kit: clerk)
    let request = Task { try await engine.invoke(.init(receiver: .clerk, method: "signOut", arguments: [])) }
    for _ in 0 ..< 1000 {
      if transport.callCount == 1 { break }
      await Task.yield()
    }
    #expect(transport.callCount == 1)
    engine.invalidate()
    await #expect(throws: CancellationError.self) { try await request.value }
    #expect(clerk.session?.id == "sess_fixture")
    await host.dispose()
  }

  private func request(for clerk: Clerk) throws -> WatchOperationRequest {
    try .init(id: UUID(), publishableKey: clerk.publishableKey, clientId: clerk.client?.id, sessionId: clerk.session?.id, invocation: JSONValue(encoding: ClerkJSInvocation(receiver: .clerk, method: "signOut", arguments: [])))
  }
}

@MainActor
private final class WatchOperationTransport: WatchConnectivitySyncing {
  var callCount = 0
  var operation: ((Data) async throws -> Data)?
  func sync(_: WatchSyncPayload) {}
  func requestOperation(_ data: Data) async throws -> Data {
    callCount += 1
    guard let operation else { throw URLError(.cannotConnectToHost) }
    return try await operation(data)
  }
}
#endif
