@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkResponseClientStateTests {
  @Test
  func applyResponseClientSetsFirstClient() {
    configureClerkForTesting()
    let incoming = client(id: "client-first", updatedAt: 2000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(incoming)

    #expect(Clerk.shared.client?.id == incoming.id)
  }

  @Test
  func applyResponseClientWithoutSequenceReplacesExistingClient() {
    configureClerkForTesting()
    let current = client(id: "client-current", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-replacement", updatedAt: 2000, lastActiveSessionId: "session-b")
    Clerk.shared.client = current

    Clerk.shared.applyResponseClient(replacement)

    #expect(Clerk.shared.client?.id == replacement.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-b")
  }

  @Test
  func applyResponseClientAcceptsNewerResponseSequenceEvenWhenUpdatedAtIsOlder() {
    configureClerkForTesting()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 4000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 3000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(original, responseSequence: 1)
    Clerk.shared.applyResponseClient(replacement, responseSequence: 2)

    #expect(Clerk.shared.client?.signIn?.id == replacement.signIn?.id)
  }

  @Test
  func applyResponseClientIgnoresOlderResponseSequenceEvenWhenUpdatedAtIsNewer() {
    configureClerkForTesting()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let stale = client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 5000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(original, responseSequence: 2)
    Clerk.shared.applyResponseClient(stale, responseSequence: 1)

    #expect(Clerk.shared.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientNilIgnoresOlderResponseSequence() {
    configureClerkForTesting()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(original, responseSequence: 2)
    Clerk.shared.applyResponseClientNil(responseSequence: 1)

    #expect(Clerk.shared.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyWatchSyncedClientAcceptsNewerSyncAnchor() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
    Clerk.shared.client = nil
    let original = client(id: "client-original", signInId: "sign-in-a", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-original", signInId: "sign-in-b", updatedAt: 3000, lastActiveSessionId: "session-b")

    Clerk.shared.applyWatchSyncedClient(
      original,
      syncedAt: Date(timeIntervalSince1970: 1),
      incomingIsAuthoritative: false
    )

    Clerk.shared.applyWatchSyncedClient(
      replacement,
      syncedAt: Date(timeIntervalSince1970: 2),
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-b")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-b")
  }

  @Test
  func applyWatchSyncedClientIgnoresEqualSyncAnchorWhenCurrentDeviceRetainsPriority() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
    Clerk.shared.client = nil
    let original = client(id: "client-original", signInId: "sign-in-a", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-original", signInId: "sign-in-b", updatedAt: 3000, lastActiveSessionId: "session-b")

    Clerk.shared.applyWatchSyncedClient(
      original,
      syncedAt: Date(timeIntervalSince1970: 2),
      incomingIsAuthoritative: false
    )

    Clerk.shared.applyWatchSyncedClient(
      replacement,
      syncedAt: Date(timeIntervalSince1970: 2),
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-a")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-a")
  }

  @Test
  func applyWatchSyncedClientIgnoresOlderSyncAnchor() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
    Clerk.shared.client = nil
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let stale = client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 3000, lastActiveSessionId: "session-stale")

    Clerk.shared.applyWatchSyncedClient(
      current,
      syncedAt: Date(timeIntervalSince1970: 3),
      incomingIsAuthoritative: false
    )

    Clerk.shared.applyWatchSyncedClient(
      stale,
      syncedAt: Date(timeIntervalSince1970: 2),
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-current")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-current")
  }

  @Test
  func applyWatchSyncedClientOverridesPreviouslyAppliedResponseSequenceWithNewerSyncAnchor() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
    Clerk.shared.client = nil
    let responseClient = client(id: "client-original", signInId: "sign-in-a", updatedAt: 3000, lastActiveSessionId: "session-a")
    let syncedClient = client(id: "client-original", signInId: "sign-in-b", updatedAt: 3000, lastActiveSessionId: "session-b")

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(responseClient, responseSequence: 10)

    Clerk.shared.applyWatchSyncedClient(
      syncedClient,
      syncedAt: .distantFuture,
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-b")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-b")
  }

  @Test
  func cleanupManagersResetsLastAppliedClientResponseSequence() {
    configureClerkForTesting()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 2000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(original, responseSequence: 10)

    Clerk.shared.cleanupManagers()
    Clerk.shared.applyResponseClient(replacement, responseSequence: 1)

    #expect(Clerk.shared.client?.signIn?.id == replacement.signIn?.id)
  }

  @Test
  func applyWatchSyncedClientCanApplyAuthoritativeIncomingState() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let replacement = client(id: "client-replacement", signInId: "sign-in-replacement", updatedAt: 3000, lastActiveSessionId: "session-replacement")

    Clerk.shared.applyResponseClient(current, responseSequence: 10)
    Clerk.shared.applyWatchSyncedClient(
      replacement,
      syncedAt: Date(timeIntervalSince1970: 1),
      incomingIsAuthoritative: true
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-replacement")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-replacement")
  }

  private func client(id: String, signInId: String? = nil, updatedAt: TimeInterval, lastActiveSessionId: String? = nil) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    client.lastActiveSessionId = lastActiveSessionId
    if let signInId {
      var signIn = SignIn.mock
      signIn.id = signInId
      client.signIn = signIn
    }
    return client
  }
}
