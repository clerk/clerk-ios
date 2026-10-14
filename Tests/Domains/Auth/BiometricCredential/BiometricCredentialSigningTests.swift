@testable import ClerkKit
import Foundation
import Testing

/// A system authentication prompt cannot be held open reliably in automated tests.
/// Exercise the real signing scheduler with a blocking Security-operation boundary.
struct BiometricCredentialSigningTests {
  @MainActor
  @Test
  func signingKeepsMainActorResponsiveAndPreservesPayload() async throws {
    let mainActorResponded = DispatchSemaphore(value: 0)
    let manager = BiometricCredentialKeyManager(signChallenge: { clientData, localKeyId, reason in
      #expect(!Thread.isMainThread)
      #expect(clientData == "{\"challenge\":\"grace\"}")
      #expect(localKeyId == "tdlk_grace")
      #expect(reason == "Use biometrics to sign in.")
      _Concurrency.Task { @MainActor in
        mainActorResponded.signal()
      }
      #expect(mainActorResponded.wait(timeout: .now() + 5) == .success)
      return .init(clientData: clientData, signature: "unchanged-signature")
    })

    let signature = try await manager.sign(
      clientData: "{\"challenge\":\"grace\"}",
      localKeyId: "tdlk_grace",
      localizedReason: "Use biometrics to sign in."
    )

    #expect(signature == .init(clientData: "{\"challenge\":\"grace\"}", signature: "unchanged-signature"))
  }

  @MainActor
  @Test(arguments: [
    BiometricCredentialKeyManagerError.keyNotFound,
    .biometricAuthenticationCanceled,
    .biometricAuthenticationFailed,
    .signingFailed("Security operation failed."),
  ])
  func signingPreservesSecurityErrors(error: BiometricCredentialKeyManagerError) async {
    let manager = BiometricCredentialKeyManager(signChallenge: { clientData, _, reason in
      #expect(clientData.isEmpty)
      #expect(reason == nil)
      throw error
    })

    await #expect(throws: error) {
      try await manager.sign(clientData: "", localKeyId: "tdlk_ada")
    }
  }

  @MainActor
  @Test
  func taskCancellationWaitsForTheSecurityOperation() async throws {
    let started = AsyncStream<Void>.makeStream()
    let finishSigning = DispatchSemaphore(value: 0)
    let manager = BiometricCredentialKeyManager(signChallenge: { clientData, _, _ in
      started.continuation.yield()
      started.continuation.finish()
      #expect(finishSigning.wait(timeout: .now() + 5) == .success)
      return .init(clientData: clientData, signature: "completed-signature")
    })
    let signing = _Concurrency.Task {
      try await manager.sign(clientData: "challenge", localKeyId: "tdlk_anna")
    }
    for await _ in started.stream {
      signing.cancel()
      finishSigning.signal()
    }

    let signature = try await signing.value
    #expect(signature == .init(clientData: "challenge", signature: "completed-signature"))
  }
}
