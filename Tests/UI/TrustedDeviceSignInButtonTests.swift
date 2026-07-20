#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import LocalAuthentication
import Testing

@MainActor
struct TrustedDeviceSignInButtonTests {
  @Test
  func biometryDisplayNamesUsePlatformTerms() {
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .faceID).value == "Face ID")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .touchID).value == "Touch ID")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .opticID).value == "Optic ID")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .none).value == "biometrics")
  }

  @Test
  func biometryDisplayNamesUseMatchingSystemImages() {
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .faceID).systemImageName == "faceid")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .touchID).systemImageName == "touchid")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .opticID).systemImageName == "opticid")
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .none).systemImageName == nil)
  }

  @Test
  func biometryDisplayNamesTrackSupport() {
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .faceID).isSupported)
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .none).isSupported == false)
    #expect(TrustedDeviceBiometryDisplayName(biometryType: .faceID, isSupported: false).isSupported == false)
  }

  @Test
  func trustedDeviceCancellationIsTreatedAsUserCancellation() {
    #expect(TrustedDeviceKeyManagerError.biometricAuthenticationCanceled.isUserCancelledError)
    #expect(!TrustedDeviceKeyManagerError.biometricAuthenticationFailed.isUserCancelledError)
  }

  @Test
  func enrollmentReasonUsesRequestedPromptCopy() {
    let reason = TrustedDeviceEnrollmentStrings.enrollmentReason(
      applicationName: "My Application",
      biometryDisplayName: .init(biometryType: .faceID)
    )

    #expect(reason == "The app My Application uses Face ID to sign you in.")
  }
}

#endif
