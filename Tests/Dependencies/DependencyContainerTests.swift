//
//  DependencyContainerTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct DependencyContainerTests {
  @Test(arguments: ["", "   ", "\n\t "])
  func blankPublishableKeyIsMissing(_ publishableKey: String) {
    #expect {
      try DependencyContainer(
        publishableKey: publishableKey,
        options: .init(),
        runtimeScope: ClerkRuntimeScope(),
        keychainStorageOverride: InMemoryKeychain()
      )
    } throws: { error in
      guard case .missingPublishableKey = error as? ClerkInitializationError else { return false }
      return true
    }
  }

  @Test
  func publishableKeyThatDoesNotDecodeToAURLIsInvalid() {
    #expect {
      try DependencyContainer(
        publishableKey: "pk_test_WyQ=",
        options: .init(),
        runtimeScope: ClerkRuntimeScope(),
        keychainStorageOverride: InMemoryKeychain()
      )
    } throws: { error in
      guard case .invalidPublishableKeyFormat = error as? ClerkInitializationError else { return false }
      return true
    }
  }

  @Test
  func unconfiguredContainerHasNoPublishableKey() {
    let container = DependencyContainer.unconfigured(runtimeScope: ClerkRuntimeScope())

    #expect(container.configurationManager.publishableKey.isEmpty)
    #expect(container.configurationManager.frontendApiUrl.isEmpty)
    #expect(container.configurationManager.proxyConfiguration == nil)
    #expect(!container.identityIsInAccessGroup)
  }

  @Test
  func anUnconfiguredClerkHasNoPublishableKey() {
    let clerk = Clerk()

    #expect(clerk.publishableKey.isEmpty)
    #expect(clerk.frontendApiUrl.isEmpty)
  }
}
