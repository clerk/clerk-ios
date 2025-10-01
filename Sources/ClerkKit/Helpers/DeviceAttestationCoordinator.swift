import Foundation

/// Coordinates App Attest requests triggered by Clerk state changes.
final class DeviceAttestationCoordinator {
  func attestIfNeeded(with environment: Clerk.Environment) {
    guard !AppAttestHelper.hasKeyId,
          [.onboarding, .enforced].contains(environment.fraudSettings?.native.deviceAttestationMode) else {
      return
    }

    Task {
      do {
        try await AppAttestHelper.performDeviceAttestation()
      } catch {
        Logger.log(level: .error, message: "Device attestation failed", error: error)
      }
    }
  }
}
