#if os(iOS)

@testable import ClerkKit

/// Test publishable key that decodes to mock.clerk.accounts.dev.
private let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

/// Configures Clerk for UI-focused unit tests.
///
/// These tests only exercise pure view-model and routing helpers, so they do not
/// need the Mocker-backed API client setup used by `ClerkKitTests`.
@MainActor
func configureClerkForTesting() {
  Clerk.configure(publishableKey: testPublishableKey)
  Clerk.shared.cleanupManagers()
}

#endif
