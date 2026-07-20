#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Testing

struct AuthStartViewTrustedDeviceTests {
  @Test
  func trustedDeviceAvailabilityRefreshStateReflectsFeatureAndSession() {
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: false,
        activeSessionID: nil,
        clientID: nil
      ) == .disabled
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: false,
        activeSessionID: "sess_123",
        clientID: "client_123"
      ) == .disabled
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: true,
        activeSessionID: nil,
        clientID: nil
      ) == .signedOut(clientID: nil)
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: true,
        activeSessionID: nil,
        clientID: "client_123"
      ) == .signedOut(clientID: "client_123")
    )
    #expect(
      AuthStartTrustedDeviceRefreshState.state(
        trustedDeviceFeatureIsEnabled: true,
        activeSessionID: "sess_123",
        clientID: "client_123"
      ) == .disabled
    )
  }

  @Test
  func signedOutClientChangesTrustedDeviceAvailabilityRefreshTaskIdentity() {
    let missingClientTaskID = AuthStartTrustedDeviceRefreshState.state(
      trustedDeviceFeatureIsEnabled: true,
      activeSessionID: nil,
      clientID: nil
    )
    let restoredClientTaskID = AuthStartTrustedDeviceRefreshState.state(
      trustedDeviceFeatureIsEnabled: true,
      activeSessionID: nil,
      clientID: "client_123"
    )

    #expect(missingClientTaskID != restoredClientTaskID)
  }
}

#endif
