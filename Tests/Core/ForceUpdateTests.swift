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
  func isForceUpdateRequiredReflectsAppVersionSupportStatus() {
    let clerk = Clerk()
    clerk.appVersionSupportStatus = .init(
      isSupported: false,
      minimumVersion: "2.0.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123456789")
    )

    #expect(clerk.isForceUpdateRequired)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }
}
