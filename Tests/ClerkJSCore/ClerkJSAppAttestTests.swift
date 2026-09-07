#if !os(watchOS)
#if canImport(DeviceCheck)
import DeviceCheck
#endif
@testable import ClerkJSCore
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"
private let clientDataHash = Data(repeating: 7, count: 32)
private let hashPayload = #"{"clientDataHash":"\#(clientDataHash.base64EncodedString())"}"#

struct ClerkJSAppAttestTests {
  @Test
  func parseReadsClientDataHash() throws {
    let request = try ClerkJSAppAttestCeremony.parse(hashPayload).get()
    #expect(request.clientDataHash == clientDataHash)
  }

  @Test
  func parseRejectsInvalidJSON() {
    let result = ClerkJSAppAttestCeremony.parse("not-json")
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "device_attest_invalid_payload")
  }

  @Test
  func parseRejectsMissingHash() {
    let result = ClerkJSAppAttestCeremony.parse("{}")
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "device_attest_invalid_payload")
  }

  @Test
  func parseRejectsWrongLengthHash() {
    let result = ClerkJSAppAttestCeremony.parse(
      #"{"clientDataHash":"\#(Data([1, 2, 3]).base64EncodedString())"}"#
    )
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "device_attest_invalid_payload")
  }

  @Test
  func parseRejectsNonStringHash() {
    let result = ClerkJSAppAttestCeremony.parse(#"{"clientDataHash":1}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "device_attest_invalid_payload")
  }

  @Test
  func mapsCancellationError() {
    let error = ClerkJSAppAttestError.from(CancellationError())
    #expect(error.code == "device_attest_cancelled")
  }

  #if canImport(DeviceCheck)
  @Test
  func mapsFeatureUnsupported() {
    let error = ClerkJSAppAttestError.from(DCError(.featureUnsupported))
    #expect(error.code == "device_attest_unavailable")
  }

  @Test
  func mapsInvalidKey() {
    let error = ClerkJSAppAttestError.from(DCError(.invalidKey))
    #expect(error.code == "device_attest_missing_key")
  }
  #endif

  @Test
  func attestReturnsProofFromPerformer() async throws {
    let ceremony = ClerkJSAppAttestCeremony()
    let probe = RequestProbe()
    ceremony.attestPerformer = { request in
      probe.request = request
      return DeviceAttestationProof(keyId: "key_1", attestation: Data([255, 254, 1]))
    }
    let proof = try await ceremony.attest(payload: hashPayload).get()
    #expect(proof.keyId == "key_1")
    #expect(proof.attestation == Data([255, 254, 1]))
    #expect(probe.request?.clientDataHash == clientDataHash)
    #expect(await ceremony.keyIdStore.get() == "key_1")
  }

  @Test
  func attestRejectsEmptyProof() async {
    let ceremony = ClerkJSAppAttestCeremony()
    ceremony.attestPerformer = { _ in
      DeviceAttestationProof(keyId: "  ", attestation: Data())
    }
    let result = await ceremony.attest(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected invalid payload")
      return
    }
    #expect(error.code == "device_attest_invalid_payload")
    #expect(await ceremony.keyIdStore.get() == nil)
  }

  @Test
  func attestMapsPerformerCancellation() async {
    let ceremony = ClerkJSAppAttestCeremony()
    ceremony.attestPerformer = { _ in
      throw CancellationError()
    }
    let result = await ceremony.attest(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected cancel")
      return
    }
    #expect(error.code == "device_attest_cancelled")
  }

  @Test
  func attestCancelInterruptsPerformer() async throws {
    let ceremony = ClerkJSAppAttestCeremony()
    let hang = HangAttestProbe()
    ceremony.attestPerformer = { _ in
      try await withCheckedThrowingContinuation { continuation in
        hang.continuation = continuation
      }
    }
    async let started = ceremony.attest(payload: hashPayload)
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
    #expect(error.code == "device_attest_cancelled")
    hang.continuation?.resume(throwing: CancellationError())
  }

  @Test
  func attestWithoutPerformerIsUnavailableOnSimulator() async {
    let ceremony = ClerkJSAppAttestCeremony()
    let result = await ceremony.attest(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected unavailable without a real DeviceCheck ceremony")
      return
    }
    #expect(error.code == "device_attest_unavailable")
  }

  @Test
  func assertReturnsProofFromPerformer() async throws {
    let ceremony = ClerkJSAppAttestCeremony()
    ceremony.assertPerformer = { request in
      #expect(request.clientDataHash == clientDataHash)
      return DeviceAssertionProof(keyId: "key_1", assertion: Data([1, 2, 3]))
    }
    let proof = try await ceremony.assert(payload: hashPayload).get()
    #expect(proof.keyId == "key_1")
    #expect(proof.assertion == Data([1, 2, 3]))
  }

  @Test
  func assertWithoutKeyIsMissingKey() async {
    let ceremony = ClerkJSAppAttestCeremony()
    let result = await ceremony.assert(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected missing key")
      return
    }
    #expect(error.code == "device_attest_missing_key")
  }

  @Test
  func assertWithStoredKeyIsUnavailableOnSimulator() async {
    let ceremony = ClerkJSAppAttestCeremony()
    await ceremony.keyIdStore.set("key_1")
    let result = await ceremony.assert(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected unavailable without a real DeviceCheck ceremony")
      return
    }
    #expect(error.code == "device_attest_unavailable")
  }

  @Test
  func assertMapsUnavailable() async {
    let ceremony = ClerkJSAppAttestCeremony()
    ceremony.assertPerformer = { _ in
      throw ClerkJSAppAttestError.unavailable
    }
    let result = await ceremony.assert(payload: hashPayload)
    guard case .failure(let error) = result else {
      Issue.record("Expected unavailable")
      return
    }
    #expect(error.code == "device_attest_unavailable")
  }

  @Test
  func nativeBridgesAreInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let attest = try await decodeJSONString(runtime.evaluateJSON("typeof __clerkNativePrepareDeviceAttestation"))
    let assertion = try await decodeJSONString(runtime.evaluateJSON("typeof __clerkNativePrepareDeviceAssertion"))
    #expect(attest == "function")
    #expect(assertion == "function")
  }

  @Test
  func hooksAreInstalledOnClerkInstance() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeHookProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appAttestHookInstallSource)
          return {
            attestType: typeof clerk.__internal_prepareDeviceAttestation,
            assertType: typeof clerk.__internal_prepareDeviceAssertion,
            nativeAttest: typeof __clerkNativePrepareDeviceAttestation,
            nativeAssert: typeof __clerkNativePrepareDeviceAssertion
          };
        })()
        """
      )
    )
    #expect(payload.attestType == "function")
    #expect(payload.assertType == "function")
    #expect(payload.nativeAttest == "function")
    #expect(payload.nativeAssert == "function")
  }

  @Test
  func hookReturnsAttestationProof() async throws {
    let runtime = ClerkJSRuntime()
    runtime.appAttestCeremony.attestPerformer = { _ in
      DeviceAttestationProof(keyId: "key_1", attestation: Data([255, 254, 1]))
    }
    let payload = try await decodeAttestation(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appAttestHookInstallSource)
          return await clerk.__internal_prepareDeviceAttestation({
            clientDataHash: '\(clientDataHash.base64EncodedString())'
          });
        })()
        """
      )
    )
    #expect(payload.keyId == "key_1")
    #expect(payload.attestation == Data([255, 254, 1]).base64EncodedString())
  }

  @Test
  func hookRejectsInvalidPayload() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appAttestHookInstallSource)
          try {
            await clerk.__internal_prepareDeviceAttestation({});
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
    #expect(payload.code == "device_attest_invalid_payload")
  }

  @Test
  func hookRejectsAssertionCancellation() async throws {
    let runtime = ClerkJSRuntime()
    runtime.appAttestCeremony.assertPerformer = { _ in
      throw CancellationError()
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appAttestHookInstallSource)
          try {
            await clerk.__internal_prepareDeviceAssertion({
              clientDataHash: '\(clientDataHash.base64EncodedString())'
            });
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
    #expect(payload.code == "device_attest_cancelled")
  }

  @Test
  func hookRejectsUnavailable() async throws {
    let runtime = ClerkJSRuntime()
    runtime.appAttestCeremony.attestPerformer = { _ in
      throw ClerkJSAppAttestError.unavailable
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appAttestHookInstallSource)
          try {
            await clerk.__internal_prepareDeviceAttestation({
              clientDataHash: '\(clientDataHash.base64EncodedString())'
            });
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
    #expect(payload.code == "device_attest_unavailable")
  }

  @Test
  @MainActor
  func clerkFacadeReturnsAttestation() async throws {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.appAttestCeremony.attestPerformer = { _ in
      DeviceAttestationProof(keyId: "key_1", attestation: Data([9]))
    }
    let proof = try await clerk.prepareDeviceAttestation(DeviceAttestParams(clientDataHash: clientDataHash))
    #expect(proof.keyId == "key_1")
    #expect(proof.attestation == Data([9]))
  }

  @Test
  @MainActor
  func clerkFacadeReturnsAssertion() async throws {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.appAttestCeremony.assertPerformer = { _ in
      DeviceAssertionProof(keyId: "key_1", assertion: Data([8]))
    }
    let proof = try await clerk.prepareDeviceAssertion(DeviceAttestParams(clientDataHash: clientDataHash))
    #expect(proof.keyId == "key_1")
    #expect(proof.assertion == Data([8]))
  }

  @Test
  @MainActor
  func clerkFacadeMapsCancel() async {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.appAttestCeremony.attestPerformer = { _ in
      throw CancellationError()
    }
    do {
      _ = try await clerk.prepareDeviceAttestation(DeviceAttestParams(clientDataHash: clientDataHash))
      Issue.record("Expected cancel")
    } catch {
      #expect(error as? ClerkJSCoreError == .cancelled)
    }
  }

  @Test
  @MainActor
  func clerkFacadeMapsUnavailable() async {
    let clerk = ClerkJSHost(publishableKey: mockPublishableKey)
    clerk.runtime.appAttestCeremony.assertPerformer = { _ in
      throw ClerkJSAppAttestError.unavailable
    }
    do {
      _ = try await clerk.prepareDeviceAssertion(DeviceAttestParams(clientDataHash: clientDataHash))
      Issue.record("Expected unavailable")
    } catch {
      #expect(error as? ClerkJSCoreError == .javascript(ClerkJSAppAttestError.unavailable.message))
    }
  }
}

private final class RequestProbe: @unchecked Sendable {
  var request: ClerkJSAppAttestRequest?
}

private final class HangAttestProbe: @unchecked Sendable {
  var continuation: CheckedContinuation<DeviceAttestationProof, Error>?
}

private struct HookProbe: Decodable {
  var attestType: String
  var assertType: String
  var nativeAttest: String
  var nativeAssert: String
}

private struct AttestationPayload: Decodable {
  var keyId: String
  var attestation: String
}

private struct Thrown: Decodable {
  var threw: Bool
  var code: String
  var message: String
}

private func decodeHookProbe(_ json: String) throws -> HookProbe {
  try JSONDecoder().decode(HookProbe.self, from: Data(json.utf8))
}

private func decodeAttestation(_ json: String) throws -> AttestationPayload {
  try JSONDecoder().decode(AttestationPayload.self, from: Data(json.utf8))
}

private func decodeThrown(_ json: String) throws -> Thrown {
  try JSONDecoder().decode(Thrown.self, from: Data(json.utf8))
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}
#endif
