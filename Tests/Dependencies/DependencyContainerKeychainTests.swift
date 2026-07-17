//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

struct DependencyContainerKeychainTests {
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
    #expect(container.appLocalKeychain is SystemKeychain)
    #expect(container.identityKeychain is SystemKeychain)
  }

  @Test
  func stableIdentityServiceIsStablePerAppAndClerkInstance() {
    let firstInstance = DependencyContainer.stableIdentityService(
      configuredService: "custom.shared.service",
      frontendApiUrl: "https://first.clerk.accounts.dev"
    )
    let normalizedFirstInstance = DependencyContainer.stableIdentityService(
      configuredService: "custom.shared.service",
      frontendApiUrl: "https://first.clerk.accounts.dev/"
    )
    let secondInstance = DependencyContainer.stableIdentityService(
      configuredService: "custom.shared.service",
      frontendApiUrl: "https://second.clerk.accounts.dev"
    )

    #expect(firstInstance == normalizedFirstInstance)
    #expect(firstInstance != secondInstance)
  }

  @Test
  func legacyAppLocalServiceUsesOnlyADifferentBundleIdentifier() {
    #expect(
      DependencyContainer.legacyAppLocalService(
        configuredService: "com.example.shared",
        bundleIdentifier: "com.example.app"
      ) == "com.example.app"
    )
    #expect(
      DependencyContainer.legacyAppLocalService(
        configuredService: "com.example.app",
        bundleIdentifier: "com.example.app"
      ) == nil
    )
    #expect(
      DependencyContainer.legacyAppLocalService(
        configuredService: "com.example.shared",
        bundleIdentifier: nil
      ) == nil
    )
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
    #expect(container.appLocalKeychain is SystemKeychain)
    #expect(container.identityKeychain is MigratingKeychainStorage)
  }

  @Test
  @MainActor
  func sharedSyncWithAccessGroupUsesAppLocalIdentityStorage() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "service",
          accessGroup: "group.example"
        ),
        sharedSessionSync: .enabled
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )

    #expect(container.keychain is MigratingKeychainStorage)
    #expect(container.appLocalKeychain is SystemKeychain)
    #expect(container.identityKeychain is SystemKeychain)
  }
  #endif
}
