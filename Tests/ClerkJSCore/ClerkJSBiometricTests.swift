#if !os(watchOS)
@testable import ClerkJSCore
import Foundation
import LocalAuthentication
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSBiometricTests {
  @Test
  func parseDefaultsPolicyAndReason() throws {
    let request = try ClerkJSBiometricCeremony.parse("{}").get()
    #expect(request.policy == .biometryCurrentSet)
    #expect(request.reason == "Verify your identity")
  }

  @Test
  func parseReadsPolicyAndReason() throws {
    let request = try ClerkJSBiometricCeremony.parse(
      #"{"policy":"biometry_or_device_passcode","reason":"Unlock Clerk"}"#
    ).get()
    #expect(request.policy == .biometryOrDevicePasscode)
    #expect(request.reason == "Unlock Clerk")
  }

  @Test
  func parseRejectsUnknownPolicy() {
    let result = ClerkJSBiometricCeremony.parse(#"{"policy":"faceID"}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "biometric_invalid_payload")
  }

  @Test
  func parseRejectsNonStringReason() {
    let result = ClerkJSBiometricCeremony.parse(#"{"reason":1}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "biometric_invalid_payload")
  }

  @Test
  func mapsUserCancel() {
    let error = ClerkJSBiometricError.from(LAError(.userCancel))
    #expect(error.code == "biometric_authentication_canceled")
  }

  @Test
  func mapsBiometryUnavailable() {
    let error = ClerkJSBiometricError.from(LAError(.biometryNotAvailable))
    #expect(error.code == "biometric_authentication_unavailable")
  }

  @Test
  func presenceReturnsAvailable() async throws {
    let ceremony = ClerkJSBiometricCeremony()
    ceremony.presenceReader = { request in
      #expect(request.policy == .biometryAny)
      return BiometricPresence(isAvailable: true, biometry: .faceID)
    }
    let presence = try await ceremony.presence(payload: #"{"policy":"biometry_any"}"#).get()
    #expect(presence.isAvailable)
    #expect(presence.biometry == .faceID)
    #expect(presence.unavailableReason == nil)
  }

  @Test
  func presenceReturnsUnavailable() async throws {
    let ceremony = ClerkJSBiometricCeremony()
    ceremony.presenceReader = { _ in
      BiometricPresence(
        isAvailable: false,
        biometry: .none,
        unavailableReason: ClerkJSBiometricError.unavailable.code
      )
    }
    let presence = try await ceremony.presence(payload: "{}").get()
    #expect(!presence.isAvailable)
    #expect(presence.unavailableReason == "biometric_authentication_unavailable")
  }

  @Test
  func promptReturnsAuthentication() async throws {
    let ceremony = ClerkJSBiometricCeremony()
    ceremony.performer = { request in
      #expect(request.policy == .biometryCurrentSet)
      return BiometricAuthentication(biometry: .touchID)
    }
    let authentication = try await ceremony.prompt(payload: "{}").get()
    #expect(authentication.biometry == .touchID)
  }

  @Test
  func promptMapsCancellation() async {
    let ceremony = ClerkJSBiometricCeremony()
    ceremony.performer = { _ in
      throw CancellationError()
    }
    let result = await ceremony.prompt(payload: "{}")
    guard case .failure(let error) = result else {
      Issue.record("Expected cancel")
      return
    }
    #expect(error.code == "biometric_authentication_canceled")
  }

  @Test
  func promptMapsUnavailable() async {
    let ceremony = ClerkJSBiometricCeremony()
    ceremony.performer = { _ in
      throw ClerkJSBiometricError.unavailable
    }
    let result = await ceremony.prompt(payload: "{}")
    guard case .failure(let error) = result else {
      Issue.record("Expected unavailable")
      return
    }
    #expect(error.code == "biometric_authentication_unavailable")
  }

  @Test
  func promptCancelInterruptsPerformer() async throws {
    let ceremony = ClerkJSBiometricCeremony()
    let hang = HangProbe()
    ceremony.performer = { _ in
      try await withCheckedThrowingContinuation { continuation in
        hang.continuation = continuation
      }
    }
    async let started = ceremony.prompt(payload: "{}")
    for _ in 0 ..< 100 where hang.continuation == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(hang.continuation != nil)
    ceremony.cancel()
    let result = await started
    guard case .failure(let error) = result else {
      Issue.record("Expected cancel")
      hang.continuation?.resume(throwing: CancellationError())
      return
    }
    #expect(error.code == "biometric_authentication_canceled")
    hang.continuation?.resume(throwing: CancellationError())
  }

  @Test
  func nativeBridgesAreInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let presence = try await decodeJSONString(runtime.evaluateJSON("typeof __clerkNativeBiometricPresence"))
    let prompt = try await decodeJSONString(runtime.evaluateJSON("typeof __clerkNativePromptBiometrics"))
    #expect(presence == "function")
    #expect(prompt == "function")
  }

  @Test
  func hooksAreInstalledOnClerkInstance() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeHookProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.biometricHookInstallSource)
          return {
            presenceType: typeof clerk.__internal_biometricPresence,
            promptType: typeof clerk.__internal_promptBiometrics,
            nativePresence: typeof __clerkNativeBiometricPresence,
            nativePrompt: typeof __clerkNativePromptBiometrics
          };
        })()
        """
      )
    )
    #expect(payload.presenceType == "function")
    #expect(payload.promptType == "function")
    #expect(payload.nativePresence == "function")
    #expect(payload.nativePrompt == "function")
  }

  @Test
  func hookReturnsPresence() async throws {
    let runtime = ClerkJSRuntime()
    runtime.biometricCeremony.presenceReader = { _ in
      BiometricPresence(isAvailable: true, biometry: .faceID)
    }
    let payload = try await decodePresence(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.biometricHookInstallSource)
          return await clerk.__internal_biometricPresence({ policy: 'biometry_current_set' });
        })()
        """
      )
    )
    #expect(payload.isAvailable)
    #expect(payload.biometry == "faceID")
  }

  @Test
  func hookRejectsPromptCancellation() async throws {
    let runtime = ClerkJSRuntime()
    runtime.biometricCeremony.performer = { _ in
      throw LAError(.userCancel)
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.biometricHookInstallSource)
          try {
            await clerk.__internal_promptBiometrics();
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "biometric_authentication_canceled")
  }

  @Test
  func hookRejectsPromptUnavailable() async throws {
    let runtime = ClerkJSRuntime()
    runtime.biometricCeremony.performer = { _ in
      throw ClerkJSBiometricError.unavailable
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.biometricHookInstallSource)
          try {
            await clerk.__internal_promptBiometrics();
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "biometric_authentication_unavailable")
  }

  @Test
  @MainActor
  func clerkFacadeReturnsPresence() async throws {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.biometricCeremony.presenceReader = { _ in
      BiometricPresence(isAvailable: true, biometry: .opticID)
    }
    let presence = try await clerk.biometricPresence()
    #expect(presence.isAvailable)
    #expect(presence.biometry == .opticID)
  }

  @Test
  @MainActor
  func clerkFacadeMapsCancel() async {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.biometricCeremony.performer = { _ in
      throw LAError(.userCancel)
    }
    do {
      _ = try await clerk.promptBiometrics()
      Issue.record("Expected cancel")
    } catch {
      #expect(error as? ClerkJSCoreError == .cancelled)
    }
  }

  @Test
  @MainActor
  func clerkFacadeMapsUnavailable() async {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.biometricCeremony.performer = { _ in
      throw ClerkJSBiometricError.unavailable
    }
    do {
      _ = try await clerk.promptBiometrics()
      Issue.record("Expected unavailable")
    } catch {
      #expect(error as? ClerkJSCoreError == .javascript(ClerkJSBiometricError.unavailable.message))
    }
  }
}

private final class HangProbe: @unchecked Sendable {
  var continuation: CheckedContinuation<BiometricAuthentication, Error>?
}

private struct HookProbe: Decodable {
  var presenceType: String
  var promptType: String
  var nativePresence: String
  var nativePrompt: String
}

private struct PresencePayload: Decodable {
  var isAvailable: Bool
  var biometry: String
  var unavailableReason: String?
}

private struct Thrown: Decodable {
  var threw: Bool
  var code: String
  var message: String
}

private func decodeHookProbe(_ json: String) throws -> HookProbe {
  try JSONDecoder().decode(HookProbe.self, from: Data(json.utf8))
}

private func decodePresence(_ json: String) throws -> PresencePayload {
  try JSONDecoder().decode(PresencePayload.self, from: Data(json.utf8))
}

private func decodeThrown(_ json: String) throws -> Thrown {
  try JSONDecoder().decode(Thrown.self, from: Data(json.utf8))
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}
#endif
