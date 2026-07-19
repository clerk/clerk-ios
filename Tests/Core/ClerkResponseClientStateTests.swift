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
  func applyResponseClientAcceptsOlderResponseSequenceWhenServerDateIsNewer() async throws {
    let clerk = makeIsolatedClerk()
    let refreshedBeforeCompletion = client(id: "client-current", signUpId: "sign-up-pending", updatedAt: 3000)
    var completed = client(id: "client-current", updatedAt: 4000, lastActiveSessionId: "session-pending")
    var pendingSession = Session.mock
    pendingSession.id = "session-pending"
    pendingSession.status = .pending
    pendingSession.tasks = [.chooseOrganization]
    completed.sessions = [pendingSession]

    clerk.client = nil
    clerk.applyResponseClient(
      refreshedBeforeCompletion,
      responseSequence: 2,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let event = try await captureNextAuthEvent(from: clerk) {
      clerk.applyResponseClient(
        completed,
        responseSequence: 1,
        serverDate: Date(timeIntervalSince1970: 101)
      )
    }

    #expect(clerk.client?.currentSession?.id == "session-pending")
    #expect(clerk.client?.currentSession?.tasks == [.chooseOrganization])

    guard case .sessionChanged(let oldValue, let newValue) = event else {
      Issue.record("Expected sessionChanged but received \(String(describing: event))")
      return
    }

    #expect(oldValue == nil)
    #expect(newValue?.id == "session-pending")
  }

  @Test
  func applyResponseClientAcceptsOlderResponseSequenceWhenServerDateTiesAndClientUpdatedAtIsNewer() {
    let clerk = makeIsolatedClerk()
    let refreshedBeforeCompletion = client(id: "client-current", signUpId: "sign-up-pending", updatedAt: 3000)
    var completed = client(id: "client-current", updatedAt: 4000, lastActiveSessionId: "session-pending")
    var pendingSession = Session.mock
    pendingSession.id = "session-pending"
    pendingSession.status = .pending
    pendingSession.tasks = [.chooseOrganization]
    completed.sessions = [pendingSession]
    let serverDate = Date(timeIntervalSince1970: 100)

    clerk.client = nil
    clerk.applyResponseClient(refreshedBeforeCompletion, responseSequence: 2, serverDate: serverDate)
    clerk.applyResponseClient(completed, responseSequence: 1, serverDate: serverDate)

    #expect(clerk.client?.currentSession?.id == "session-pending")
    #expect(clerk.client?.currentSession?.tasks == [.chooseOrganization])
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

  @Test
  func organizationReturnsActiveSessionOrganization() {
    configureClerkForTesting()
    var organization = Organization.mock
    organization.id = "org-active"
    organization.name = "Active Organization"

    var membership = OrganizationMembership.mockWithUserData
    membership.id = "orgmem-active"
    membership.organization = organization

    var user = User.mock
    user.organizationMemberships = [membership]

    var session = Session.mock
    session.id = "session-active"
    session.lastActiveOrganizationId = organization.id
    session.user = user

    var client = Client.mock
    client.sessions = [session]
    client.lastActiveSessionId = session.id

    Clerk.shared.applyResponseClient(client)

    #expect(Clerk.shared.organization?.id == organization.id)
    #expect(Clerk.shared.organization?.name == "Active Organization")
    #expect(Clerk.shared.organizationMembership?.id == membership.id)
  }

  @Test
  func organizationReturnsNilWhenSessionHasNoActiveOrganization() {
    configureClerkForTesting()
    var session = Session.mock
    session.id = "session-personal"
    session.lastActiveOrganizationId = nil
    session.user = .mock

    var client = Client.mock
    client.sessions = [session]
    client.lastActiveSessionId = session.id

    Clerk.shared.applyResponseClient(client)

    #expect(Clerk.shared.organization == nil)
    #expect(Clerk.shared.organizationMembership == nil)
  }

  // MARK: - Watch Sync (Authoritative / Phone → Watch)

  @Test
  func watchReducerCanApplyAuthoritativeIncomingState() {
    let clerk = makeIsolatedClerk()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000, lastActiveSessionId: "session-current")
    let replacement = client(id: "client-replacement", signInId: "sign-in-replacement", updatedAt: 3000, lastActiveSessionId: "session-replacement")

    clerk.applyResponseClient(current, responseSequence: 10)
    applyRemoteAuthPayload(
      replacement,
      incomingServerFetchDate: Date(timeIntervalSince1970: 1),
      incomingIsAuthoritative: true,
      to: clerk
    )

    #expect(clerk.client?.lastActiveSessionId == "session-replacement")
    #expect(clerk.client?.signIn?.id == "sign-in-replacement")
  }

  @Test
  func watchReducerAuthoritativeNilClearsClient() {
    let clerk = makeIsolatedClerk()
    let current = client(id: "client-current", signInId: "sign-in-current", updatedAt: 4000)
    clerk.applyResponseClient(current, responseSequence: 10)

    applyRemoteAuthPayload(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: true,
      to: clerk
    )

    #expect(clerk.client == nil)
  }

  // MARK: - Watch Sync (Non-authoritative / Watch → Phone)

  @Test
  func nonAuthoritativeWatchSyncRefreshesInsteadOfReplacingActivePhone() {
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 100)
    let watchServerDate = Date(timeIntervalSince1970: 200)

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false,
      to: clerk
    )

    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-phone")
    #expect(clerk.lastClientServerFetchDate == phoneServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncSameVersionRefreshesWhenLocalVersionExists() async throws {
    let serverClient = client(id: "client-server", signInId: "sign-in-server", updatedAt: 5000)
    let refreshed = LockIsolated(false)
    let clerk = makeIsolatedClerk(
      clientService: MockClientService {
        refreshed.setValue(true)
        return serverClient
      }
    )
    let keychain = clerk.dependencies.keychain
    try keychain.set("set", forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    try keychain.set("3", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))
    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: Date(timeIntervalSince1970: 200),
      incomingIsAuthoritative: false,
      version: WatchSyncVersion(rawValue: 3),
      to: clerk
    )

    #expect(clerk.client?.id == phoneClient.id)
    try await waitUntil {
      clerk.client?.id == serverClient.id
    }
    #expect(refreshed.value)
  }

  @Test
  func nonAuthoritativeWatchSyncKeepsPhoneClientWhenServerFetchDateIsOlder() {
    let clerk = makeIsolatedClerk()
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 5000, lastActiveSessionId: "session-watch")
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let watchServerDate = Date(timeIntervalSince1970: 100)

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false,
      to: clerk
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
    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false,
      to: clerk
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
    applyRemoteAuthPayload(
      nil,
      incomingServerFetchDate: Date(timeIntervalSince1970: 200),
      incomingIsAuthoritative: false,
      to: clerk
    )

    // Even with a newer server fetch date, nil is not accepted from watch.
    // Only the server can sign out the phone.
    #expect(clerk.client?.id == phoneClient.id)
  }

  @Test
  func nonAuthoritativeWatchSyncClearDoesNotPublishStalePhoneClientAsCleared() throws {
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000)
    let clerk = makeIsolatedClerk(clientService: MockClientService { phoneClient })
    let keychain = clerk.dependencies.keychain
    let phoneServerDate = Date(timeIntervalSince1970: 100)
    let clearServerDate = Date(timeIntervalSince1970: 200)
    let coordinator = WatchConnectivityCoordinator()

    clerk.applyResponseClient(phoneClient, responseSequence: 1, serverDate: phoneServerDate)
    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .cleared(serverFetchDate: clearServerDate, version: WatchSyncVersion(rawValue: 3)),
      environment: nil
    )

    coordinator.apply(clearPayload, from: .watch, to: clerk)
    let outgoingPayload = try WatchSyncPayload(
      clerk: clerk,
      metadata: WatchSyncMetadataStore(keychain: keychain).load(),
      authGeneration: coordinator.currentAuthVersion(keychain: keychain)
    )

    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.lastClientServerFetchDate == phoneServerDate)
    #expect((try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)) == nil)
    #expect((try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)) == nil)

    guard case let .snapshot(client, serverFetchDate, version) = outgoingPayload.clientUpdate else {
      Issue.record("Expected outgoing phone client snapshot")
      return
    }

    #expect(client.id == phoneClient.id)
    #expect(serverFetchDate == phoneServerDate)
    #expect(version == .initial)
  }

  @Test
  func nonAuthoritativeWatchSyncSeedsPhoneWhenNoLocalClient() {
    let clerk = makeIsolatedClerk()
    clerk.client = nil
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    let watchServerDate = Date(timeIntervalSince1970: 100)

    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: watchServerDate,
      incomingIsAuthoritative: false,
      to: clerk
    )

    #expect(clerk.client?.id == watchClient.id)
    #expect(clerk.client?.lastActiveSessionId == "session-watch")
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func nonAuthoritativeWatchSyncNilDoesNotSeedPhone() {
    let clerk = makeIsolatedClerk()
    clerk.client = nil

    applyRemoteAuthPayload(
      nil,
      incomingServerFetchDate: nil,
      incomingIsAuthoritative: false,
      to: clerk
    )

    #expect(clerk.client == nil)
  }

  @Test
  func nonAuthoritativeWatchSyncClearRecordsVersionWhenLocalAuthIsEmpty() throws {
    let clerk = makeIsolatedClerk()
    let keychain = clerk.dependencies.keychain
    let clearServerDate = Date(timeIntervalSince1970: 200)
    let staleServerDate = Date(timeIntervalSince1970: 300)
    clerk.client = nil

    applyRemoteAuthPayload(
      nil,
      incomingServerFetchDate: clearServerDate,
      incomingIsAuthoritative: false,
      version: WatchSyncVersion(rawValue: 3),
      to: clerk
    )

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == clearServerDate)
    #expect(try WatchSyncMetadataStore(keychain: keychain).load().authState == .cleared)
    #expect(try WatchSyncMetadataStore(keychain: keychain).load().authVersion == 3)

    applyRemoteAuthPayload(
      client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 4000),
      incomingServerFetchDate: staleServerDate,
      incomingIsAuthoritative: false,
      version: WatchSyncVersion(rawValue: 2),
      to: clerk
    )

    #expect(clerk.client == nil)
    #expect(try WatchSyncMetadataStore(keychain: keychain).load().authState == .cleared)
    #expect(try WatchSyncMetadataStore(keychain: keychain).load().authVersion == 3)
  }

  @Test
  func nonAuthoritativeWatchSignInWithLowerVersionRefreshesPhone() async throws {
    let serverClient = client(id: "client-server", signInId: "sign-in-server", updatedAt: 5000)
    let refreshed = LockIsolated(false)
    let clerk = makeIsolatedClerk(
      clientService: MockClientService {
        refreshed.setValue(true)
        return serverClient
      }
    )
    let keychain = clerk.dependencies.keychain
    try keychain.set("cleared", forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    try keychain.set("3", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 200)
    clerk.client = nil

    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 4000)
    applyRemoteAuthPayload(
      watchClient,
      incomingServerFetchDate: Date(timeIntervalSince1970: 300),
      incomingIsAuthoritative: false,
      version: WatchSyncVersion(rawValue: 1),
      to: clerk
    )

    #expect(clerk.client == nil)
    try await waitUntil {
      clerk.client?.id == serverClient.id
    }
    #expect(refreshed.value)
  }

  // MARK: - Cleanup

  @Test
  func cleanupManagersResetsLastAppliedClientResponseSequence() {
    let clerk = makeIsolatedClerk()
    let original = client(id: "client-original", signInId: "sign-in-old", updatedAt: 3000)
    let replacement = client(id: "client-replacement", signInId: "sign-in-new", updatedAt: 2000)
    let pendingSignIn = SignIn(
      id: "sign_in_pending",
      status: .needsSecondFactor,
      createdSessionId: nil
    )

    clerk.client = nil
    clerk.applyResponseClient(original, responseSequence: 10)
    clerk.setCallbackContinuation(.signIn(pendingSignIn))

    clerk.cleanupManagers()
    clerk.applyResponseClient(replacement, responseSequence: 1)

    #expect(clerk.client?.signIn?.id == replacement.signIn?.id)
    #expect(clerk.callbackContinuation == nil)
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

  private func applyRemoteAuthPayload(
    _ incoming: Client?,
    incomingServerFetchDate: Date?,
    incomingIsAuthoritative: Bool,
    version: WatchSyncVersion? = nil,
    to clerk: Clerk
  ) {
    let deviceTokenUpdate: WatchSyncDeviceTokenUpdate
    if incoming != nil {
      let token = (try? clerk.dependencies.identityKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )) ?? "watch-test-token"
      deviceTokenUpdate = .tokenSet(token: token, version: version)
    } else {
      deviceTokenUpdate = .notIncluded
    }
    let clientUpdate: WatchSyncClientUpdate = if let incoming {
      .snapshot(client: incoming, serverFetchDate: incomingServerFetchDate, version: version)
    } else {
      .cleared(serverFetchDate: incomingServerFetchDate, version: version)
    }
    let source: WatchSyncSource = incomingIsAuthoritative ? .phone : .watch
    let payload = WatchSyncPayload(
      deviceTokenUpdate: deviceTokenUpdate,
      clientUpdate: clientUpdate,
      environment: nil
    )
    WatchConnectivityCoordinator().apply(payload, from: source, to: clerk)
  }

  private func makeIsolatedClerk(clientService: (any ClientServiceProtocol)? = nil) -> Clerk {
    configureClerkForTesting()

    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: clientService ?? MockClientService(get: { nil })
    )
    try! (clerk.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
    return clerk
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(250),
    condition: @MainActor () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(condition())
  }
}
