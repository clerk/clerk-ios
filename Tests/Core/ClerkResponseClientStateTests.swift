@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct ClerkResponseClientStateTests {
  @Test
  func applyResponseClientSetsFirstClient() {
    let incoming = client(id: "client-first", updatedAt: 2000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(incoming)

    #expect(clerk.client?.id == incoming.id)
  }

  @Test
  func applyResponseClientWithoutSequenceReplacesExistingClient() {
    let current = client(id: "client-current", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-replacement", updatedAt: 2000, lastActiveSessionId: "session-b")
    let clerk = makeBareClerk()
    clerk.client = current

    clerk.applyResponseClient(replacement)

    #expect(clerk.client?.id == replacement.id)
    #expect(clerk.client?.lastActiveSessionId == "session-b")
  }

  @Test
  func applyResponseClientAcceptsNewerResponseSequenceEvenWhenUpdatedAtIsOlder() {
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 4000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 3000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 1)
    clerk.applyResponseClient(replacement, responseSequence: 2)

    #expect(clerk.client?.signIn?.id == replacement.signIn?.id)
  }

  @Test
  func applyResponseClientIgnoresOlderResponseSequenceEvenWhenUpdatedAtIsNewer() {
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let stale = client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 5000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 2)
    clerk.applyResponseClient(stale, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientNilIgnoresOlderResponseSequence() {
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 2)
    clerk.applyResponseClient(nil, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientStoresServerDate() {
    let serverDate = Date(timeIntervalSince1970: 1000)
    let incoming = client(id: "client-1", updatedAt: 2000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(incoming, serverDate: serverDate)

    #expect(clerk.lastClientServerFetchDate == serverDate)
  }

  // MARK: - Watch Sync (Authoritative / Phone → Watch)

  @Test
  func applyWatchSyncedClientCanApplyAuthoritativeIncomingState() {
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let replacement = client(id: "client-replacement", signInId: "sign-in-replacement", updatedAt: 3000, lastActiveSessionId: "session-replacement")
    let clerk = makeBareClerk()

    clerk.applyResponseClient(current, responseSequence: 10)
    clerk.applyWatchSyncedClient(
      replacement,
      incomingServerFetchDate: Date(timeIntervalSince1970: 1),
      incomingIsAuthoritative: true
    )

    #expect(clerk.client?.lastActiveSessionId == "session-replacement")
    #expect(clerk.client?.signIn?.id == "sign-in-replacement")
  }

  @Test
  func applyWatchSyncedClientAuthoritativeNilClearsClient() {
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000)
    let clerk = makeBareClerk()
    clerk.applyResponseClient(current, responseSequence: 10)

    clerk.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: true
    )

    #expect(clerk.client == nil)
  }

  // MARK: - Watch Sync (Non-authoritative / Watch → Phone)

  @Test
  func nonAuthoritativeWatchSyncAcceptsNewerServerFetchDate() {
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 100)
    let watchServerDate = Date(timeIntervalSince1970: 200)
    let clerk = makeBareClerk()

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    clerk.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(clerk.client?.id == watchClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-watch")
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncKeepsPhoneClientWhenServerFetchDateIsOlder() {
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let watchServerDate = Date(timeIntervalSince1970: 100)
    let clerk = makeBareClerk()

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    clerk.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-phone")
  }

  @Test
  func nonAuthoritativeWatchSyncSchedulesRefreshWhenNoServerFetchDates() {
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")
    let clerk = makeBareClerk()

    clerk.applyResponseClient(phoneClient, responseSequence: 1)
    clerk.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false
    )

    // Without server fetch dates, phone keeps its client (defers to server refresh)
    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-phone")
  }

  @Test
  func nonAuthoritativeWatchSyncNilDoesNotClearPhoneClient() {
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000)
    let clerk = makeBareClerk()

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))
    clerk.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: Date(timeIntervalSince1970: 200),
      incomingIsAuthoritative: false
    )

    // Even with a newer server fetch date, nil is not accepted from watch.
    // Only the server can sign out the phone.
    #expect(clerk.client?.id == phoneClient.id)
  }

  @Test
  func nonAuthoritativeWatchSyncSeedsPhoneWhenNoLocalClient() {
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let watchServerDate = Date(timeIntervalSince1970: 100)
    let clerk = makeBareClerk()
    clerk.client = nil

    clerk.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(clerk.client?.id == watchClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-watch")
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncNilDoesNotSeedPhone() {
    let clerk = makeBareClerk()
    clerk.client = nil

    clerk.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false
    )

    #expect(clerk.client == nil)
  }

  // MARK: - Cleanup

  @Test
  func cleanupManagersResetsLastAppliedClientResponseSequence() {
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 2000)
    let clerk = makeBareClerk()

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 10)

    clerk.cleanupManagers()
    clerk.applyResponseClient(replacement, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == replacement.signIn?.id)
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
