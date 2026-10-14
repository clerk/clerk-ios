#if os(iOS)

@testable import ClerkKit

/// Test publishable key that decodes to mock.clerk.accounts.dev.
private let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

@MainActor
func configureClerkForTesting() {
  Clerk.configure(publishableKey: testPublishableKey)
}

#endif
