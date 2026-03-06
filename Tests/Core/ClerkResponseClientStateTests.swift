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
  func applyResponseClientIgnoresOlderClient() {
    configureClerkForTesting()
    let current = client(id: "client-newer", updatedAt: 3000)
    let stale = client(id: "client-stale", updatedAt: 2000)
    Clerk.shared.client = current

    Clerk.shared.applyResponseClient(stale)

    #expect(Clerk.shared.client?.id == current.id)
  }

  @Test
  func applyResponseClientIgnoresEqualTimestampClient() {
    configureClerkForTesting()
    let current = client(id: "client-current", updatedAt: 3000)
    let incoming = client(id: "client-same-time", updatedAt: 3000)
    Clerk.shared.client = current

    Clerk.shared.applyResponseClient(incoming)

    #expect(Clerk.shared.client?.id == current.id)
  }

  @Test
  func applyResponseClientAcceptsNewerClient() {
    configureClerkForTesting()
    let current = client(id: "client-current", updatedAt: 2000)
    let newer = client(id: "client-newer", updatedAt: 4000)
    Clerk.shared.client = current

    Clerk.shared.applyResponseClient(newer)

    #expect(Clerk.shared.client?.id == newer.id)
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
  func applyWatchSyncedClientAcceptsSessionSwitchAtSameTimestamp() {
    configureClerkForTesting()
    let original = client(id: "client-original", signInId: "sign-in-a", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-original", signInId: "sign-in-b", updatedAt: 3000, lastActiveSessionId: "session-b")

    Clerk.shared.client = original

    Clerk.shared.applyWatchSyncedClient(replacement)

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-b")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-b")
  }

  @Test
  func applyWatchSyncedClientOverridesPreviouslyAppliedResponseSequence() {
    configureClerkForTesting()
    let responseClient = client(id: "client-original", signInId: "sign-in-a", updatedAt: 3000, lastActiveSessionId: "session-a")
    let syncedClient = client(id: "client-original", signInId: "sign-in-b", updatedAt: 3000, lastActiveSessionId: "session-b")

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(responseClient, responseSequence: 10)

    Clerk.shared.applyWatchSyncedClient(syncedClient)

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-b")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-b")
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
