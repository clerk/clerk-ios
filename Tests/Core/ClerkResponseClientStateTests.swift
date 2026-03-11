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
    Clerk.shared.applyResponseClient(nil, responseSequence: 1)

    #expect(Clerk.shared.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientStoresServerDate() {
    configureClerkForTesting()
    let serverDate = Date(timeIntervalSince1970: 1000)
    let incoming = client(id: "client-1", updatedAt: 2000)

    Clerk.shared.client = nil
    Clerk.shared.applyResponseClient(incoming, serverDate: serverDate)

    #expect(Clerk.shared.lastClientServerFetchDate == serverDate)
  }

  // MARK: - Watch Sync (Authoritative / Phone → Watch)

  @Test
  func applyWatchSyncedClientCanApplyAuthoritativeIncomingState() {
    configureClerkForTesting()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let replacement = client(id: "client-replacement", signInId: "sign-in-replacement", updatedAt: 3000, lastActiveSessionId: "session-replacement")

    Clerk.shared.applyResponseClient(current, responseSequence: 10)
    Clerk.shared.applyWatchSyncedClient(
      replacement,
      incomingServerFetchDate: Date(timeIntervalSince1970: 1),
      incomingIsAuthoritative: true
    )

    #expect(Clerk.shared.client?.lastActiveSessionId == "session-replacement")
    #expect(Clerk.shared.client?.signIn?.id == "sign-in-replacement")
  }

  @Test
  func applyWatchSyncedClientAuthoritativeNilClearsClient() {
    configureClerkForTesting()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000)
    Clerk.shared.applyResponseClient(current, responseSequence: 10)

    Clerk.shared.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: true
    )

    #expect(Clerk.shared.client == nil)
  }

  // MARK: - Watch Sync (Non-authoritative / Watch → Phone)

  @Test
  func nonAuthoritativeWatchSyncAcceptsNewerServerFetchDate() {
    configureClerkForTesting()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 100)
    let watchServerDate = Date(timeIntervalSince1970: 200)

    Clerk.shared.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    Clerk.shared.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.id == watchClient.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-watch")
    #expect(Clerk.shared.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncKeepsPhoneClientWhenServerFetchDateIsOlder() {
    configureClerkForTesting()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let watchServerDate = Date(timeIntervalSince1970: 100)

    Clerk.shared.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    Clerk.shared.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.id == phoneClient.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-phone")
  }

  @Test
  func nonAuthoritativeWatchSyncSchedulesRefreshWhenNoServerFetchDates() {
    configureClerkForTesting()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")

    Clerk.shared.applyResponseClient(phoneClient, responseSequence: 1)
    Clerk.shared.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false
    )

    // Without server fetch dates, phone keeps its client (defers to server refresh)
    #expect(Clerk.shared.client?.id == phoneClient.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-phone")
  }

  @Test
  func nonAuthoritativeWatchSyncNilDoesNotClearPhoneClient() {
    configureClerkForTesting()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000)

    Clerk.shared.applyResponseClient(phoneClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))
    Clerk.shared.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: Date(timeIntervalSince1970: 200),
      incomingIsAuthoritative: false
    )

    // Even with a newer server fetch date, nil is not accepted from watch.
    // Only the server can sign out the phone.
    #expect(Clerk.shared.client?.id == phoneClient.id)
  }

  @Test
  func nonAuthoritativeWatchSyncSeedsPhoneWhenNoLocalClient() {
    configureClerkForTesting()
    Clerk.shared.client = nil
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let watchServerDate = Date(timeIntervalSince1970: 100)

    Clerk.shared.applyWatchSyncedClient(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client?.id == watchClient.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-watch")
    #expect(Clerk.shared.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncNilDoesNotSeedPhone() {
    configureClerkForTesting()
    Clerk.shared.client = nil

    Clerk.shared.applyWatchSyncedClient(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false
    )

    #expect(Clerk.shared.client == nil)
  }

  // MARK: - Cleanup

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
