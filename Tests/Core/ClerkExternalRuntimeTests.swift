#if !os(watchOS)
import ClerkJSCore
@_spi(ClerkExpo) @testable import ClerkKit
import ClerkSnapshots
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkExternalRuntimeTests {
  @Test
  func publicOperationsUseTheExternalOwnerAndCommitItsStateBeforeReturning() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let kit = Clerk.shared
    let initial = try state(kit, revision: 1)
    await Clerk.disposeEngine()
    let engine = ClerkExternalEngine(kit: kit, runtimeID: "external", invoke: { data in
      let invocation = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      #expect(invocation["method"] as? String == "invokeForIdentity")
      let args = try #require(invocation["arguments"] as? [[String: Any]])
      #expect(args[1]["clientId"] as? String == "client_fixture")
      #expect(args[1]["sessionId"] as? String == "sess_fixture")
      var client = try #require(kit.client)
      client.sessions = []
      client.lastActiveSessionId = nil
      try await Clerk.publishExternalRuntimeState(runtimeID: "external", state: state(kit, revision: 2, client: client))
      return Data("{\"result\":null}".utf8)
    })
    Clerk.engineClient = engine
    try await engine.publish(initial)
    try await kit.auth.signOut()
    #expect(kit.session == nil)
    #expect(kit.user == nil)
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func onlyIncreasingRevisionsFromTheCurrentRuntimeCanUpdateNativeState() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let kit = Clerk.shared
    let initial = try state(kit, revision: 1)
    await Clerk.disposeEngine()
    let engine = ClerkExternalEngine(kit: kit, runtimeID: "external", invoke: { _ in Data("{\"result\":null}".utf8) })
    Clerk.engineClient = engine
    try await engine.publish(initial)
    var client = try #require(kit.client)
    client.sessions = []
    client.lastActiveSessionId = nil
    try await engine.publish(state(kit, revision: 2, client: client))
    try await engine.publish(initial)
    #expect(kit.session == nil)
    await #expect(throws: Error.self) { try await engine.publish(state(kit, revision: 3, generation: "old")) }
    engine.invalidate()
    await #expect(throws: Error.self) { try await engine.publish(initial) }
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func rejectedSnapshotDoesNotPreventALaterValidPublication() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let kit = Clerk.shared
    let initial = try state(kit, revision: 1)
    await Clerk.disposeEngine()
    let engine = ClerkExternalEngine(kit: kit, runtimeID: "external", invoke: { _ in Data("{\"result\":null}".utf8) })
    Clerk.engineClient = engine
    defer { engine.invalidate() }
    try await engine.publish(initial)
    var rejected = try #require(JSONSerialization.jsonObject(with: state(kit, revision: 2)) as? [String: Any])
    rejected["clientToken"] = ""
    await #expect(throws: Error.self) {
      try await engine.publish(JSONSerialization.data(withJSONObject: rejected))
    }
    #expect(kit.session?.id == "sess_fixture")
    var client = try #require(kit.client)
    client.sessions = []
    client.lastActiveSessionId = nil
    try await engine.publish(state(kit, revision: 3, client: client))
    #expect(kit.user == nil)
    #expect(kit.session == nil)
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func aFailedPublicationCannotRestoreAnIdentityClearedOutsideTheRuntime() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let kit = Clerk.shared
    let initial = try state(kit, revision: 1)
    let later = try state(kit, revision: 3)
    await Clerk.disposeEngine()
    let engine = ClerkExternalEngine(kit: kit, runtimeID: "external", invoke: { _ in
      Issue.record("An invalidated owner must not receive another operation")
      return Data("{\"result\":null}".utf8)
    })
    Clerk.engineClient = engine
    try await engine.publish(initial)
    var rejected = try #require(JSONSerialization.jsonObject(with: state(kit, revision: 2)) as? [String: Any])
    rejected["clientToken"] = ""
    await #expect(throws: Error.self) {
      try await engine.publish(JSONSerialization.data(withJSONObject: rejected))
    }
    _ = try await kit.identityController.updateDeviceToken(to: "replacement-device-token")
    await #expect(throws: CancellationError.self) { try await engine.publish(later) }
    await #expect(throws: CancellationError.self) {
      _ = try await engine.invoke(.init(receiver: .clerk, method: "refreshClient", arguments: []))
    }
    #expect(kit.user == nil)
    #expect(kit.identityController.currentDeviceToken == "replacement-device-token")
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func invalidationCancelsAnOperationWaitingForJavaScript() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let kit = Clerk.shared
    await Clerk.disposeEngine()
    var started = false
    let engine = ClerkExternalEngine(kit: kit, runtimeID: "external", invoke: { _ in
      started = true
      try await Task.sleep(for: .seconds(60))
      return Data("{\"result\":null}".utf8)
    })
    Clerk.engineClient = engine
    let pending = Task { try await kit.auth.signOut() }
    while !started {
      await Task.yield()
    }
    engine.invalidate()
    await #expect(throws: CancellationError.self) { try await pending.value }
    #expect(kit.session?.id == "sess_fixture")
    await Clerk.disposeEngine()
    await host.dispose()
  }

  @Test
  func externalConfigurationInstallsNoEmbeddedHostAndRejectsAnOldConnection() async throws {
    let host = try await configureEmbeddedClerkForTesting()
    let initial = try state(Clerk.shared, revision: 1)
    let key = Clerk.shared.publishableKey
    let options = Clerk.Options(keychainConfig: .init(service: "clerk-external-test-\(UUID().uuidString)"))
    try await Clerk.configureExternalRuntime(publishableKey: key, options: options, runtimeID: "external", initialState: initial) { _ in
      Issue.record("Configuration must not ask the external owner to load or fetch a second client")
      return Data("{\"result\":null}".utf8)
    }
    #expect(Clerk.engineClient is ClerkExternalEngine)
    #expect(Clerk.shared.session?.id == "sess_fixture")
    #expect(Clerk.shared.isLoaded)
    await Clerk.detachExternalRuntime(runtimeID: "old")
    #expect(Clerk.engineClient is ClerkExternalEngine)
    await Clerk.detachExternalRuntime(runtimeID: "external")
    let detached = try await Clerk.requireEngineClient()
    await #expect(throws: CancellationError.self) { _ = try await detached.invoke(.init(receiver: .clerk, method: "refreshClient", arguments: [])) }
    try await Clerk.clearAllKeychainItemsAndWait()
    await host.dispose()
  }

  private func state(_ kit: Clerk, revision: Int, client: Client? = nil, generation: String = "external") throws -> Data {
    let client = try JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(client ?? kit.client))
    let environment = try JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(kit.environment))
    return try JSONSerialization.data(withJSONObject: [
      "protocolVersion": 1, "generation": generation, "revision": revision, "status": "ready",
      "client": client, "environment": environment, "clientToken": kit.identityController.currentDeviceToken ?? "fixture-client-jwt",
    ])
  }
}
#endif
