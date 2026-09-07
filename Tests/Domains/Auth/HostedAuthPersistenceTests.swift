#if !os(watchOS) && !os(tvOS)
import ClerkJSCore
@testable import ClerkKit
import Foundation
import Testing

extension HostedAuthFlowTests {
  @Test(arguments: [false, true])
  func persistsRedeemedIdentityBeforeActivation(shared: Bool) async throws {
    let store = HostedIdentityStore()
    let slots = HostedSlotStore()
    let host = try await hostedPersistenceHarness(store: store, slots: slots, shared: shared)
    let previous = host.onStateChange
    var checked = false
    host.onStateChange = { state in
      try await previous?(state)
      if !checked, state.client?.sessions.contains(where: { $0.id == "sess_hosted" }) == true,
         state.client?.lastActiveSessionId == "sess_fixture"
      {
        checked = true
        #expect(try store.load()?.deviceToken == "redeemed-token")
        #expect(try store.load()?.client?.sessions.contains(where: { $0.id == "sess_hosted" }) == true)
        if shared { #expect(try slots.loadOwnSlot()?.event.deviceToken == "redeemed-token") }
        #expect(try await hostedRequests(host).filter { $0.path.hasSuffix("/touch") }.isEmpty)
      }
    }
    let result = try await Clerk.shared.auth.performHostedAuth(
      mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
      webAuthentication: { _, _, _ in try await hostedCallback(host) }
    )
    #expect(checked)
    #expect(result.id == "sess_hosted")
    #expect(try store.load()?.client?.lastActiveSessionId == result.id)
    host.onStateChange = previous
    await stopHostedPersistenceHarness()
  }

  @Test(arguments: ["atomic", "shared", "publication"])
  func persistenceFailureDoesNotExposeOrActivateRedeemedIdentity(mode: String) async throws {
    let store = HostedIdentityStore(failRedeemedIdentity: mode != "publication")
    let slots = HostedSlotStore(failRedeemedIdentity: mode == "publication")
    let host = try await hostedPersistenceHarness(store: store, slots: slots, shared: mode != "atomic")
    let original = Clerk.shared.client
    await #expect(throws: (any Error).self) {
      try await Clerk.shared.auth.performHostedAuth(
        mode: nil, redirectUrl: "myapp://callback", prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in try await hostedCallback(host) }
      )
    }
    #expect(Clerk.shared.client == original)
    #expect(try store.load()?.deviceToken == "fixture-client-jwt")
    #expect(try await hostedRequests(host).filter { $0.path.hasSuffix("/touch") }.isEmpty)
    await stopHostedPersistenceHarness()
  }
}

@MainActor
private func hostedPersistenceHarness(store: HostedIdentityStore, slots: HostedSlotStore, shared: Bool) async throws -> ClerkJSHost {
  let host = try await hostedAuthHarness { clerk in
    let dependencies = MockDependencyContainer(apiClient: clerk.dependencies.apiClient, keychain: InMemoryKeychain(), atomicIdentityStore: store)
    try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init())
    clerk.dependencies = dependencies
  }
  if shared {
    let clerk = Clerk.shared
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "com.example.hosted-auth", instanceFingerprint: "hosted-auth-tests",
      slotStore: slots, localIdentityStore: store, notifier: HostedNotifier(),
      configurationEpoch: clerk.configurationEpoch, clerk: clerk, logError: { _, _ in }
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)
  }
  return host
}

@MainActor
private func stopHostedPersistenceHarness() async {
  Clerk.shared.sharedSessionSyncCoordinator?.deactivate()
  Clerk.shared.sharedSessionSyncCoordinator = nil
  await Clerk.disposeEngine()
}

private final class HostedIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private let failRedeemedIdentity: Bool

  init(failRedeemedIdentity: Bool = false) {
    self.failRedeemedIdentity = failRedeemedIdentity
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(_ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?) throws {
    try lock.withLock {
      let next = try update(record)
      if failRedeemedIdentity, next?.acceptedIdentity?.deviceToken == "redeemed-token" {
        throw CocoaError(.fileWriteNoPermission)
      }
      record = next
    }
  }
}

private final class HostedSlotStore: @unchecked Sendable, SharedSessionSlotStoring {
  private let lock = NSLock()
  private var slot: SharedSessionOwnerSlot?
  private let failRedeemedIdentity: Bool

  init(failRedeemedIdentity: Bool = false) {
    self.failRedeemedIdentity = failRedeemedIdentity
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock { slot }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock { slot.map { [$0] } ?? [] }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    try lock.withLock {
      if failRedeemedIdentity, slot.event.deviceToken == "redeemed-token" { throw CocoaError(.fileWriteNoPermission) }
      self.slot = slot
    }
  }

  func deleteOwnSlot() throws {
    lock.withLock { slot = nil }
  }
}

@MainActor
private final class HostedNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}
#endif
