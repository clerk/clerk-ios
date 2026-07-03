#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Testing

struct AuthStartViewTrustedDeviceTests {
  @Test
  func trustedDeviceAvailabilityRefreshStateReflectsFeatureAndSession() {
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: false,
        activeSessionID: nil
      ) == .disabled
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: false,
        activeSessionID: "sess_123"
      ) == .disabled
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: true,
        activeSessionID: nil
      ) == .signedOut
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: true,
        activeSessionID: "sess_123"
      ) == .signedIn(activeSessionID: "sess_123")
    )
  }

  @Test
  func activeSessionChangesTrustedDeviceAvailabilityRefreshTaskIdentity() {
    let firstSessionTaskID = AuthStartTrustedDeviceRefreshState.state(
      trustedDeviceFeatureIsEnabled: true,
      activeSessionID: "sess_123"
    )
    let secondSessionTaskID = AuthStartTrustedDeviceRefreshState.state(
      trustedDeviceFeatureIsEnabled: true,
      activeSessionID: "sess_456"
    )

    #expect(firstSessionTaskID != secondSessionTaskID)
  }
}

#endif
