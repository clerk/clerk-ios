@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  @Test
  func clerkEncoderRoundTripsGeneratedClientForWatchSync() throws {
    let encoded = try JSONEncoder.clerkEncoder.encode(Client.mock)
    let decoded = try JSONDecoder.clerkDecoder.decode(Client.self, from: encoded)
    #expect(decoded.id == Client.mock.id)
    #expect(decoded.object == "client")
    #expect(decoded.sessions.map(\.id) == Client.mock.sessions.map(\.id))
    #expect(decoded.signIn?.id == Client.mock.signIn?.id)
    #expect(decoded.signUp?.id == Client.mock.signUp?.id)
    #expect(decoded.lastUsedStrategy == .password)
  }

  @Test
  func refreshClientReturnsCachedClientWithoutEngine() async throws {
    configureClerkForTesting()
    let expectedClient = Client(
      id: "refresh-client-test",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient()
    )
    Clerk.shared.client = expectedClient

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.engineClient == nil)
  }

  @Test
  func refreshClientPreservesClientWhenCanonicalResponseRequestsPreserve() async throws {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient()
    )
    Clerk.shared.client = Client.mock

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
  }

  @Test
  func refreshClientPreservesAdoptedAtomicIdentityWhenCanonicalResponseRequestsPreserve() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "current-token",
      client: Client.mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(previous)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: identityStore
    )
    Clerk.shared.client = nil
    Clerk.shared.hydrateIdentityIfNeeded(previous)

    let client = try await Clerk.shared.refreshClient()

    let stored = try #require(try identityStore.load())
    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(stored.state == previous.state)
    #expect(stored.deviceToken == previous.deviceToken)
    #expect(stored.client?.id == previous.client?.id)
    #expect(stored.serverDate == previous.serverDate)
  }

  @Test
  func updateDeviceTokenRejectsBlankToken() async throws {
    configureClerkForTesting()

    await #expect(throws: Clerk.DeviceTokenError.emptyToken) {
      try await Clerk.shared.updateDeviceToken("   ")
    }
  }
}
