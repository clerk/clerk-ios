#if os(iOS) || os(macOS)

@testable import ClerkKit

/// Test publishable key that decodes to mock.clerk.accounts.dev.
private let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

/// Configures the shared Clerk instance for UI-focused unit tests.
@MainActor
func configureClerkForTesting() {
  try! Clerk.configureForTesting(publishableKey: testPublishableKey, keychainStorage: InMemoryKeychain())
  Clerk.shared.cleanupManagers()
}

#endif
