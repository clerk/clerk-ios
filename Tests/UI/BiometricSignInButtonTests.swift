#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import LocalAuthentication
import Testing

@MainActor
struct BiometricSignInButtonTests {
  @Test
  func biometryDisplayNamesUsePlatformTerms() {
    #expect(BiometryDisplayName(biometryType: .faceID).value == "Face ID")
    #expect(BiometryDisplayName(biometryType: .touchID).value == "Touch ID")
    #expect(BiometryDisplayName(biometryType: .opticID).value == "Optic ID")
    #expect(BiometryDisplayName(biometryType: .none).value == "biometrics")
  }

  @Test
  func biometryDisplayNamesUseMatchingSystemImages() {
    #expect(BiometryDisplayName(biometryType: .faceID).systemImageName == "faceid")
    #expect(BiometryDisplayName(biometryType: .touchID).systemImageName == "touchid")
    #expect(BiometryDisplayName(biometryType: .opticID).systemImageName == "opticid")
    #expect(BiometryDisplayName(biometryType: .none).systemImageName == nil)
  }

  @Test
  func biometryDisplayNamesTrackSupport() {
    #expect(BiometryDisplayName(biometryType: .faceID).isSupported)
    #expect(BiometryDisplayName(biometryType: .none).isSupported == false)
    #expect(BiometryDisplayName(biometryType: .faceID, isSupported: false).isSupported == false)
  }

  @Test
  func biometricCredentialCancellationIsTreatedAsUserCancellation() {
    #expect(BiometricCredentialKeyManagerError.biometricAuthenticationCanceled.isUserCancelledError)
    #expect(!BiometricCredentialKeyManagerError.biometricAuthenticationFailed.isUserCancelledError)
  }

  @Test
  func enrollmentReasonUsesRequestedPromptCopy() {
    let reason = BiometricCredentialEnrollmentStrings.enrollmentReason(
      applicationName: "My Application",
      biometryDisplayName: .init(biometryType: .faceID)
    )

    #expect(reason == "The app My Application uses Face ID to sign you in.")
  }
}

#endif
