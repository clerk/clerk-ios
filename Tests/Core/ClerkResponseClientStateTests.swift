@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkResponseClientStateTests {
  @Test
  func applyResponseClientSetsFirstClient() {
    let clerk = makeIsolatedClerk()
    let incoming = client(id: "client-first", updatedAt: 2000)

    clerk.client = nil
    clerk.applyResponseClient(incoming)

    #expect(clerk.client?.id == incoming.id)
  }

  @Test
  func applyResponseClientWithoutSequenceReplacesExistingClient() {
    let clerk = makeIsolatedClerk()
    let current = client(id: "client-current", updatedAt: 3000, lastActiveSessionId: "session-a")
    let replacement = client(id: "client-replacement", updatedAt: 2000, lastActiveSessionId: "session-b")
    clerk.client = current

    clerk.applyResponseClient(replacement)

    #expect(clerk.client?.id == replacement.id)
    #expect(clerk.client?.lastActiveSessionId == "session-b")
  }

  @Test
  func applyResponseClientAcceptsNewerResponseSequenceEvenWhenUpdatedAtIsOlder() {
    let clerk = makeIsolatedClerk()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 4000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 3000)

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 1)
    clerk.applyResponseClient(replacement, responseSequence: 2)

    #expect(clerk.client?.signIn?.id == replacement.signIn?.id)
  }

  @Test
  func applyResponseClientIgnoresOlderResponseSequenceEvenWhenUpdatedAtIsNewer() {
    let clerk = makeIsolatedClerk()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let stale = client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 5000)

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 2)
    clerk.applyResponseClient(stale, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientNilIgnoresOlderResponseSequence() {
    let clerk = makeIsolatedClerk()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 2)
    clerk.applyResponseClient(nil, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == original.signIn?.id)
  }

  @Test
  func applyResponseClientStoresServerDate() {
    let clerk = makeIsolatedClerk()
    let serverDate = Date(timeIntervalSince1970: 1000)
    let incoming = client(id: "client-1", updatedAt: 2000)

    clerk.client = nil
    clerk.applyResponseClient(incoming, serverDate: serverDate)

    #expect(clerk.lastClientServerFetchDate == serverDate)
  }

  @Test
  func applyResponseClientDoesNotEmitContinuationForResumableSignIn() async throws {
    let clerk = makeIsolatedClerk()
    let incoming = client(
      id: "client-sign-in",
      signInId: "sign-in-resumable",
      signInStatus: .needsSecondFactor,
      updatedAt: 2000
    )

    clerk.client = nil
    let event = try await captureNextAuthEvent(from: clerk) {
      clerk.applyResponseClient(incoming)
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func applyResponseClientDoesNotEmitContinuationForResumableSignUp() async throws {
    let clerk = makeIsolatedClerk()
    let incoming = client(
      id: "client-sign-up",
      signUpId: "sign-up-resumable",
      signUpStatus: .missingRequirements,
      updatedAt: 2000
    )

    clerk.client = nil
    let event = try await captureNextAuthEvent(from: clerk) {
      clerk.applyResponseClient(incoming)
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func applyResponseClientDoesNotEmitContinuationWhenResumableSignInIsUnchanged() async throws {
    let clerk = makeIsolatedClerk()
    let incoming = client(
      id: "client-sign-in",
      signInId: "sign-in-resumable",
      signInStatus: .needsSecondFactor,
      updatedAt: 2000
    )

    clerk.client = incoming
    let event = try await captureNextAuthEvent(from: clerk) {
      clerk.applyResponseClient(incoming)
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  // MARK: - Watch Sync (Authoritative / Phone → Watch)

  @Test
  func applyWatchSyncedClientCanApplyAuthoritativeIncomingState() {
    let clerk = makeIsolatedClerk()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let replacement = client(id: "client-replacement", signInId: "sign-in-replacement", updatedAt: 3000, lastActiveSessionId: "session-replacement")

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
    let clerk = makeIsolatedClerk()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000)
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
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 100)
    let watchServerDate = Date(timeIntervalSince1970: 200)

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
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let watchServerDate = Date(timeIntervalSince1970: 100)

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
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")

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
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000)

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
    let clerk = makeIsolatedClerk()
    clerk.client = nil
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let watchServerDate = Date(timeIntervalSince1970: 100)

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
    let clerk = makeIsolatedClerk()
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
    let clerk = makeIsolatedClerk()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 2000)

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 10)

    clerk.cleanupManagers()
    clerk.applyResponseClient(replacement, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == replacement.signIn?.id)
  }

  private func captureNextAuthEvent(
    from clerk: Clerk,
    timeout: Duration = .milliseconds(250),
    operation: () async throws -> Void
  ) async throws -> AuthEvent? {
    let captured = LockIsolated<AuthEvent?>(nil)
    var listener: Task<Void, Never>?
    await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
      listener = Task { @MainActor in
        var iterator = clerk.auth.events.makeAsyncIterator()
        ready.resume()
        if let event = await iterator.next() {
          captured.setValue(event)
        }
      }
    }
    defer { listener?.cancel() }

    try await operation()

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if let event = captured.value {
        return event
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    return captured.value
  }

  private func client(
    id: String,
    signInId: String? = nil,
    signInStatus: SignIn.Status = .needsFirstFactor,
    signUpId: String? = nil,
    signUpStatus: SignUp.Status = .missingRequirements,
    updatedAt: TimeInterval,
    lastActiveSessionId: String? = nil
  ) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    client.lastActiveSessionId = lastActiveSessionId
    client.signIn = nil
    client.signUp = nil
    if let signInId {
      var signIn = SignIn.mock
      signIn.id = signInId
      signIn.status = signInStatus
      client.signIn = signIn
    }
    if let signUpId {
      var signUp = SignUp.mock
      signUp.id = signUpId
      signUp.status = signUpStatus
      client.signUp = signUp
    }
    return client
  }

  private func makeIsolatedClerk() -> Clerk {
    configureClerkForTesting()

    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: MockClientService(get: { nil })
    )
    try! (clerk.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
    return clerk
  }
}
