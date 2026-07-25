@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

extension HostedAuthFlowTests {
  @Test(arguments: HostedAuthPersistenceTestMode.allCases)
  func redeemPersistsIdentityBeforeActivation(
    mode: HostedAuthPersistenceTestMode
  ) async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let persistedBeforeActivation = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock, .mock2],
      lastActiveSessionId: Session.mock.id
    )
    let activatedClient = makeHostedAuthPersistenceClient(
      id: redeemedClient.id,
      sessions: redeemedClient.sessions,
      lastActiveSessionId: Session.mock2.id
    )
    let initialIdentity = makeHostedAuthInitialIdentity()
    let identityStore = HostedAuthPersistenceIdentityStore()
    let slotStore = HostedAuthPersistenceSlotStore()

    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(
          object: "hosted_auth",
          url: "https://accounts.example.com/sign-in"
        )
      },
      redeem: { _ in
        hostedAuthRedeemResponse(client: redeemedClient)
      }
    )
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      let persistedIdentity = try identityStore.load()
      let persistedSlot = try slotStore.loadOwnSlot()
      persistedBeforeActivation.setValue(
        persistedIdentity?.deviceToken == "redeemed-token"
          && persistedIdentity?.client == redeemedClient
          && persistedIdentity?.serverDate
          == Date(timeIntervalSince1970: 200)
          && (
            mode == .atomic
              || (
                persistedSlot?.event.deviceToken == "redeemed-token"
                  && persistedSlot?.event.client == redeemedClient
              )
          )
      )
      #expect(sessionId == Session.mock2.id)
      Clerk.shared.client = activatedClient
    })
    let runtime = try configureHostedAuthPersistenceTest(
      mode: mode,
      identityStore: identityStore,
      slotStore: slotStore,
      initialIdentity: initialIdentity,
      hostedAuthService: hostedAuthService,
      sessionService: sessionService
    )
    defer { runtime.stop() }

    let session = try await Clerk.shared.auth.performHostedAuth(
      mode: nil,
      redirectUrl: "myapp://callback",
      prefersEphemeralWebBrowserSession: false,
      webAuthentication: { _, _, _ in
        try hostedAuthPersistenceCallbackURL(
          state: #require(createParams.value?.state),
          createdSessionId: Session.mock2.id
        )
      }
    )

    #expect(persistedBeforeActivation.value)
    #expect(session.id == Session.mock2.id)
    let persistedIdentity = try #require(try identityStore.load())
    #expect(persistedIdentity.deviceToken == "redeemed-token")
    #expect(persistedIdentity.client == redeemedClient)
    #expect(try identityStore.loadRecord()?.pendingPublication == nil)
    if mode == .shared {
      let slot = try #require(try slotStore.loadOwnSlot())
      #expect(slot.event.deviceToken == "redeemed-token")
      #expect(slot.event.client == redeemedClient)
    }
  }

  @Test(arguments: HostedAuthPersistenceTestMode.allCases)
  func redeemPersistenceFailureDoesNotExposeOrActivateIdentity(
    mode: HostedAuthPersistenceTestMode
  ) async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let initialIdentity = makeHostedAuthInitialIdentity()
    let identityStore = HostedAuthPersistenceIdentityStore()
    let slotStore = HostedAuthPersistenceSlotStore()
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(
          object: "hosted_auth",
          url: "https://accounts.example.com/sign-in"
        )
      },
      redeem: { _ in
        hostedAuthRedeemResponse(client: redeemedClient)
      }
    )
    let runtime = try configureHostedAuthPersistenceTest(
      mode: mode,
      identityStore: identityStore,
      slotStore: slotStore,
      initialIdentity: initialIdentity,
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in
        setActiveCalled.setValue(true)
      })
    )
    defer { runtime.stop() }
    switch mode {
    case .atomic:
      identityStore.failUpdates()
    case .shared:
      slotStore.failSaves()
    }

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?.state),
            createdSessionId: Session.mock.id
          )
        }
      )
      Issue.record("Expected identity persistence to fail.")
    } catch {
      switch mode {
      case .atomic:
        #expect(error is HostedAuthPersistenceIdentityStore.Failure)
      case .shared:
        #expect(error is HostedAuthPersistenceSlotStore.Failure)
      }
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client == initialIdentity.client)
    #expect(try identityStore.load() == initialIdentity)
    #expect(try slotStore.loadOwnSlot() == nil)
    let record = try identityStore.loadRecord()
    switch mode {
    case .atomic:
      #expect(record?.pendingPublication == nil)
    case .shared:
      #expect(record?.pendingPublication?.client == redeemedClient)
      #expect(record?.pendingPublication?.deviceToken == "redeemed-token")
    }
  }

  @Test(arguments: HostedAuthPersistenceTestMode.allCases)
  func missingCallbackSessionDoesNotMutatePersistedIdentity(
    mode: HostedAuthPersistenceTestMode
  ) async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let returnedClient = makeHostedAuthPersistenceClient(
      id: "wrong-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let initialIdentity = makeHostedAuthInitialIdentity()
    let identityStore = HostedAuthPersistenceIdentityStore()
    let slotStore = HostedAuthPersistenceSlotStore()
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(
          object: "hosted_auth",
          url: "https://accounts.example.com/sign-in"
        )
      },
      redeem: { _ in
        hostedAuthRedeemResponse(client: returnedClient)
      }
    )
    let runtime = try configureHostedAuthPersistenceTest(
      mode: mode,
      identityStore: identityStore,
      slotStore: slotStore,
      initialIdentity: initialIdentity,
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in
        setActiveCalled.setValue(true)
      })
    )
    defer { runtime.stop() }

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?.state),
            createdSessionId: "sess_not_in_response"
          )
        }
      )
      Issue.record("Expected a redeem response missing the callback session to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion did not include the created session.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error).")
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client == initialIdentity.client)
    #expect(try identityStore.load() == initialIdentity)
    #expect(try slotStore.loadOwnSlot() == nil)
  }

  @Test(arguments: HostedAuthPersistenceTestMode.allCases)
  func generationChangeBeforeRedeemSkipsRedeemAndPreservesIdentity(
    mode: HostedAuthPersistenceTestMode
  ) async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let redeemCalled = LockIsolated(false)
    let setActiveCalled = LockIsolated(false)
    let initialIdentity = makeHostedAuthInitialIdentity()
    let identityStore = HostedAuthPersistenceIdentityStore()
    let slotStore = HostedAuthPersistenceSlotStore()
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(
          object: "hosted_auth",
          url: "https://accounts.example.com/sign-in"
        )
      },
      redeem: { _ in
        redeemCalled.setValue(true)
        return hostedAuthRedeemResponse(client: .mock)
      }
    )
    let runtime = try configureHostedAuthPersistenceTest(
      mode: mode,
      identityStore: identityStore,
      slotStore: slotStore,
      initialIdentity: initialIdentity,
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in
        setActiveCalled.setValue(true)
      })
    )
    defer { runtime.stop() }

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          Clerk.shared.identityController.fenceClientResponses()
          return try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?.state),
            createdSessionId: Session.mock.id
          )
        }
      )
      Issue.record("Expected the stale hosted-auth flow to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion could not update the current client.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error).")
    }

    #expect(!redeemCalled.value)
    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client == initialIdentity.client)
    #expect(try identityStore.load() == initialIdentity)
    #expect(try slotStore.loadOwnSlot() == nil)
  }

  @Test
  func sharedFrontierAdvanceDuringRedeemRejectsResponseWithoutActivating() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let initialIdentity = makeHostedAuthInitialIdentity()
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let newerSharedClient = makeHostedAuthPersistenceClient(
      id: "newer-shared-client",
      sessions: [],
      lastActiveSessionId: nil
    )
    let identityStore = HostedAuthPersistenceIdentityStore()
    let slotStore = HostedAuthPersistenceSlotStore()
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(
          object: "hosted_auth",
          url: "https://accounts.example.com/sign-in"
        )
      },
      redeem: { _ in
        let response = hostedAuthRedeemResponse(client: redeemedClient)
        let responseGeneration = Clerk.shared.clientResponseGeneration
        let coordinator = try #require(Clerk.shared.sharedSessionSyncCoordinator)
        let didPublish = try await coordinator.publishLocalIdentity(
          state: .present,
          deviceToken: "initial-token",
          client: newerSharedClient,
          serverDate: Date(timeIntervalSince1970: 150)
        )
        #expect(didPublish)
        #expect(Clerk.shared.clientResponseGeneration == responseGeneration)
        return response
      }
    )
    let runtime = try configureHostedAuthPersistenceTest(
      mode: .shared,
      identityStore: identityStore,
      slotStore: slotStore,
      initialIdentity: initialIdentity,
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in
        setActiveCalled.setValue(true)
      })
    )
    defer { runtime.stop() }

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?.state),
            createdSessionId: Session.mock.id
          )
        }
      )
      Issue.record("Expected the stale shared-frontier response to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion could not update the current client.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error).")
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client == newerSharedClient)
    #expect(try identityStore.load()?.client == newerSharedClient)
    #expect(try slotStore.loadOwnSlot()?.event.client == newerSharedClient)
  }
}

enum HostedAuthPersistenceTestMode: String, CaseIterable {
  case atomic
  case shared
}

@MainActor
private struct HostedAuthPersistenceTestRuntime {
  let coordinator: SharedSessionSyncCoordinator?

  func stop() {
    coordinator?.deactivate()
    if Clerk.shared.sharedSessionSyncCoordinator === coordinator {
      Clerk.shared.sharedSessionSyncCoordinator = nil
    }
  }
}

@MainActor
private func configureHostedAuthPersistenceTest(
  mode: HostedAuthPersistenceTestMode,
  identityStore: HostedAuthPersistenceIdentityStore,
  slotStore: HostedAuthPersistenceSlotStore,
  initialIdentity: ClerkIdentitySnapshot,
  hostedAuthService: some HostedAuthServiceProtocol,
  sessionService: some SessionServiceProtocol
) throws -> HostedAuthPersistenceTestRuntime {
  configureClerkForTesting()
  let clerk = Clerk.shared
  clerk.sharedSessionSyncCoordinator?.deactivate()
  clerk.sharedSessionSyncCoordinator = nil
  clerk.identityController.resetRuntimeIdentity()
  try identityStore.save(initialIdentity)

  let apiClient = createMockAPIClient(runtimeScope: clerk.runtimeScope)
  let dependencies = MockDependencyContainer(
    apiClient: apiClient,
    keychain: InMemoryKeychain(),
    atomicIdentityStore: identityStore,
    sharedSessionOwnerIdentifier: "com.example.hosted-auth",
    hostedAuthService: hostedAuthService,
    sessionService: sessionService
  )
  try dependencies.configurationManager.configure(
    publishableKey: testPublishableKey,
    options: Clerk.Options(
      sharedSessionSync: mode == .shared ? .enabled : nil
    )
  )
  clerk.dependencies = dependencies
  clerk.hydrateIdentityIfNeeded(initialIdentity)

  guard mode == .shared else {
    return HostedAuthPersistenceTestRuntime(coordinator: nil)
  }

  let coordinator = SharedSessionSyncCoordinator(
    ownerIdentifier: "com.example.hosted-auth",
    instanceFingerprint: "hosted-auth-tests",
    slotStore: slotStore,
    localIdentityStore: identityStore,
    notifier: HostedAuthPersistenceNotifier(),
    configurationEpoch: clerk.configurationEpoch,
    clerk: clerk,
    logError: { _, _ in }
  )
  clerk.sharedSessionSyncCoordinator = coordinator
  clerk.internalStateChanges.addObserver(coordinator)
  return HostedAuthPersistenceTestRuntime(coordinator: coordinator)
}

@MainActor
private func hostedAuthRedeemResponse(
  client: Client
) -> HostedAuthRedeemResponse {
  HostedAuthRedeemResponse(
    client: client,
    clientSyncContext: ClientSyncResponseContext(
      update: .client(client),
      deviceTokenUpdate: .set("redeemed-token"),
      requestDeviceToken: "initial-token",
      baseGeneration: 0,
      serverDate: Date(timeIntervalSince1970: 200),
      isCanonicalClientRequest: true,
      clientResponseGeneration: Clerk.shared.clientResponseGeneration,
      responseSequence: 1
    )
  )
}

private func makeHostedAuthInitialIdentity() -> ClerkIdentitySnapshot {
  ClerkIdentitySnapshot(
    state: .present,
    deviceToken: "initial-token",
    client: makeHostedAuthPersistenceClient(
      id: "initial-client",
      sessions: [],
      lastActiveSessionId: nil
    ),
    serverDate: Date(timeIntervalSince1970: 100)
  )
}

private func makeHostedAuthPersistenceClient(
  id: String,
  sessions: [Session],
  lastActiveSessionId: String?
) -> Client {
  var client = Client.mockSignedOut
  client.id = id
  client.sessions = sessions
  client.lastActiveSessionId = lastActiveSessionId
  return client
}

private func hostedAuthPersistenceCallbackURL(
  state: String,
  createdSessionId: String
) throws -> URL {
  var components = try #require(URLComponents(string: "myapp://callback"))
  components.queryItems = [
    URLQueryItem(name: "state", value: state),
    URLQueryItem(name: "rotating_token_nonce", value: "nonce_123"),
    URLQueryItem(name: "created_session_id", value: createdSessionId),
  ]
  return try #require(components.url)
}

private final class HostedAuthPersistenceIdentityStore: @unchecked Sendable,
  SharedSessionLocalIdentityStoring
{
  enum Failure: Error {
    case update
  }

  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldFailUpdates = false

  func failUpdates() {
    lock.withLock {
      shouldFailUpdates = true
    }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      guard !shouldFailUpdates else { throw Failure.update }
      record = try update(record)
    }
  }
}

private final class HostedAuthPersistenceSlotStore: @unchecked Sendable,
  SharedSessionSlotStoring
{
  enum Failure: Error {
    case save
  }

  private let lock = NSLock()
  private var slot: SharedSessionOwnerSlot?
  private var shouldFailSaves = false

  func failSaves() {
    lock.withLock {
      shouldFailSaves = true
    }
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock { slot }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock { slot.map { [$0] } ?? [] }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    try lock.withLock {
      guard !shouldFailSaves else { throw Failure.save }
      self.slot = slot
    }
  }

  func deleteOwnSlot() throws {
    lock.withLock {
      slot = nil
    }
  }
}

@MainActor
private final class HostedAuthPersistenceNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}
