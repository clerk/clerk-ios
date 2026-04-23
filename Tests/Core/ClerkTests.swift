@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.tags(.unit))
struct ClerkTests {
  func createSession(
    id: String,
    status: Session.SessionStatus,
    user: User? = .mock
  ) -> Session {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    return Session(
      id: id,
      status: status,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      latestActivity: nil,
      lastActiveOrganizationId: nil,
      actor: nil,
      user: user,
      publicUserData: nil,
      createdAt: date,
      updatedAt: date,
      tasks: nil,
      lastActiveToken: nil
    )
  }

  func makeClerk() -> Clerk {
    Clerk()
  }

  @Test
  func clearAllKeychainItemsDeletesAllKeys() throws {
    let keychain = InMemoryKeychain()

    try keychain.set(#require("test-client-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set(#require("test-date-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try keychain.set(#require("test-environment-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    // Verify all keys exist before clearing
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == true)
    }

    Clerk.clearAllKeychainItems(using: keychain)

    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func clearAllKeychainItemsHandlesMissingKeysGracefully() throws {
    let keychain = InMemoryKeychain()

    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    Clerk.clearAllKeychainItems(using: keychain)

    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func clearAllKeychainItemsWorksWhenClerkNotConfigured() throws {
    let keychain = InMemoryKeychain()

    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    Clerk.clearAllKeychainItems(using: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func clearAllKeychainItemsDoesNotThrow() throws {
    let keychain = InMemoryKeychain()

    try keychain.set("test-data", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    Clerk.clearAllKeychainItems(using: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  // MARK: - isLoaded Tests

  @Test
  func isLoadedReturnsFalseWhenBothNil() {
    let clerk = makeClerk()
    clerk.client = nil
    clerk.environment = nil
    #expect(clerk.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyEnvironmentSet() {
    let clerk = makeClerk()
    clerk.environment = Clerk.Environment.mock
    clerk.client = nil
    #expect(clerk.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyClientSet() {
    let clerk = makeClerk()
    clerk.client = Client.mock
    clerk.environment = nil
    #expect(clerk.isLoaded == false)
  }

  @Test
  func isLoadedReturnsTrueWhenBothSet() {
    let clerk = makeClerk()
    clerk.client = Client.mock
    clerk.environment = Clerk.Environment.mock
    #expect(clerk.isLoaded == true)
  }

  @Test
  func isLoadedBecomesTrue() {
    let clerk = makeClerk()
    clerk.client = nil
    clerk.environment = nil
    #expect(clerk.isLoaded == false)

    clerk.client = Client.mock
    #expect(clerk.isLoaded == false)

    clerk.environment = Clerk.Environment.mock
    #expect(clerk.isLoaded == true)

    clerk.client = nil
    #expect(clerk.isLoaded == false)
  }

  // MARK: - Current / Active Session Tests

  @Test
  func sessionReturnsPendingSession() {
    let clerk = makeClerk()
    let pendingSession = createSession(id: "session1", status: .pending)
    clerk.client = Client(
      id: "client1",
      sessions: [pendingSession],
      lastActiveSessionId: "session1",
      updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
    )

    #expect(clerk.session?.id == "session1")
  }

  @Test
  func userReturnsUserForPendingSession() {
    let clerk = makeClerk()
    let pendingSession = createSession(id: "session1", status: .pending, user: .mock)
    clerk.client = Client(
      id: "client1",
      sessions: [pendingSession],
      lastActiveSessionId: "session1",
      updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
    )

    #expect(clerk.user?.id == User.mock.id)
  }
}
