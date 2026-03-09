@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct WatchSyncPayloadTests {
  @Test
  func applicationContextRoundTripsPayloadValues() throws {
    let syncAnchor = Date(timeIntervalSince1970: 123)
    let payload = WatchSyncPayload(
      deviceToken: "device-token",
      client: client(id: "client-1", signInId: "sign-in-1", updatedAt: 2000, lastActiveSessionId: "session-1"),
      environment: .mock,
      clientSyncAnchor: syncAnchor
    )

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))

    #expect(decoded.deviceToken == "device-token")
    #expect(decoded.client?.id == "client-1")
    #expect(decoded.client?.signIn?.id == "sign-in-1")
    #expect(decoded.client?.lastActiveSessionId == "session-1")
    #expect(decoded.environment == .mock)
    #expect(decoded.clientSyncAnchor == syncAnchor)
  }

  @Test
  func applicationContextMarksMissingClientWithEmptyData() throws {
    let payload = WatchSyncPayload(
      deviceToken: "device-token",
      client: nil,
      environment: nil,
      clientSyncAnchor: Date(timeIntervalSince1970: 1)
    )

    let encodedClient = try #require(payload.applicationContext["clerkClient"] as? Data)
    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))

    #expect(encodedClient.isEmpty)
    #expect(decoded.client == nil)
  }

  @Test
  func phonePayloadAppliesAuthoritativeClientAndWinsFirstDeviceTokenSync() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("watch-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 10
    )

    let payload = WatchSyncPayload(
      deviceToken: "phone-token",
      client: client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone"),
      environment: .mock,
      clientSyncAnchor: Date(timeIntervalSince1970: 1)
    )

    payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-phone")
    #expect(clerk.client?.signIn?.id == "sign-in-phone")
    #expect(clerk.environment == .mock)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadDoesNotRollBackNewerLocalStateOrFirstSyncDeviceToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 10
    )

    let payload = WatchSyncPayload(
      deviceToken: "watch-token",
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      environment: nil,
      clientSyncAnchor: Date(timeIntervalSince1970: 1)
    )

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
    #expect(clerk.client?.signIn?.id == "sign-in-local")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
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
