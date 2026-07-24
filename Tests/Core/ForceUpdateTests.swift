@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct ForceUpdateTests {
  @Test
  func isForceUpdateRequiredIsFalseWhenEnvironmentIsMissing() {
    let clerk = Clerk()

    #expect(clerk.isForceUpdateRequired == false)
  }

  @Test
  func isForceUpdateRequiredReflectsResolvedEnvironmentValue() {
    var environment = Clerk.Environment.mock
    environment.forceUpdate = .init(
      required: true,
      minimumAppVersion: "2.0.0",
      appStoreURL: URL(string: "https://apps.apple.com/app/id123456789")
    )

    let clerk = Clerk()
    clerk.environment = environment

    #expect(clerk.isForceUpdateRequired)
    #expect(clerk.environment?.forceUpdate.required == true)
    #expect(clerk.environment?.forceUpdate.minimumAppVersion == "2.0.0")
    #expect(
      clerk.environment?.forceUpdate.appStoreURL?.absoluteString
        == "https://apps.apple.com/app/id123456789"
    )
  }
}
