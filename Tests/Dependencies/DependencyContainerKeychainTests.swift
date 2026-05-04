//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Testing

struct DependencyContainerKeychainTests {
  @Test
  @MainActor
  func keychainStorageWithoutAccessGroupUsesSystemKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service")
      )
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
      )
    )

    #expect(container.keychain is MigratingKeychainStorage)
  }
  #endif
}
