//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Testing

struct DependencyContainerKeychainTests {
  @Test
  @MainActor
  func sharedSessionSyncFailsClosedWithoutAccessGroup() {
    #expect(throws: ClerkClientError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(sharedSessionSync: .enabled),
        runtimeScope: ClerkRuntimeScope(epoch: .initial)
      )
    }
  }

  @Test
  @MainActor
  func sharedSessionSyncFailsClosedWithoutOwnerIdentifier() {
    #expect(throws: ClerkClientError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(
          keychainConfig: .init(service: "service", accessGroup: "group.example"),
          sharedSessionSync: .enabled
        ),
        runtimeScope: ClerkRuntimeScope(epoch: .initial),
        ownerIdentifierProvider: { nil }
      )
    }
  }

  @Test
  @MainActor
  func keychainStorageWithoutAccessGroupUsesSystemKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service")
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )

    #expect(container.keychain is SystemKeychain)
  }

  #if os(macOS)
  @Test
  @MainActor
  func keychainStorageWithAccessGroupUsesMigratingStorage() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "service",
          accessGroup: "group.example"
        )
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )

    #expect(container.keychain is MigratingKeychainStorage)
  }
  #endif
}
