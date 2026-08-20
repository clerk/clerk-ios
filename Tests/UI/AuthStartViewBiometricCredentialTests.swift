#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Testing

struct AuthStartViewBiometricCredentialTests {
  @Test
  func biometricCredentialAvailabilityRefreshStateReflectsFeatureAndSession() {
    #expect(
      AuthStartBiometricCredentialRefreshState.state(
        biometricCredentialFeatureIsEnabled: false,
        activeSessionID: nil,
        clientID: nil
      ) == .disabled
    )
    #expect(
      AuthStartBiometricCredentialRefreshState.state(
        biometricCredentialFeatureIsEnabled: false,
        activeSessionID: "sess_123",
        clientID: "client_123"
      ) == .disabled
    )
    #expect(
      AuthStartBiometricCredentialRefreshState.state(
        biometricCredentialFeatureIsEnabled: true,
        activeSessionID: nil,
        clientID: nil
      ) == .signedOut(clientID: nil)
    )
    #expect(
      AuthStartBiometricCredentialRefreshState.state(
        biometricCredentialFeatureIsEnabled: true,
        activeSessionID: nil,
        clientID: "client_123"
      ) == .signedOut(clientID: "client_123")
    )
    #expect(
      AuthStartBiometricCredentialRefreshState.state(
        biometricCredentialFeatureIsEnabled: true,
        activeSessionID: "sess_123",
        clientID: "client_123"
      ) == .disabled
    )
  }

  @Test
  func signedOutClientChangesBiometricCredentialAvailabilityRefreshTaskIdentity() {
    let missingClientTaskID = AuthStartBiometricCredentialRefreshState.state(
      biometricCredentialFeatureIsEnabled: true,
      activeSessionID: nil,
      clientID: nil
    )
    let restoredClientTaskID = AuthStartBiometricCredentialRefreshState.state(
      biometricCredentialFeatureIsEnabled: true,
      activeSessionID: nil,
      clientID: "client_123"
    )

    #expect(missingClientTaskID != restoredClientTaskID)
  }
}

#endif
