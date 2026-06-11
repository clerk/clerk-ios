@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct PasskeyTests {
  init() {
    configureClerkForTesting()
  }

  private func configureService(_ service: MockPasskeyService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      passkeyService: service
    )
  }

  @Test
  func updateUsesPasskeyServiceUpdate() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockPasskeyService(update: { passkeyId, name in
      captured.setValue((passkeyId, name))
      return .mock
    })

    configureService(service)

    _ = try await passkey.update(name: "New Name")

    let params = try #require(captured.value)
    #expect(params.0 == passkey.id)
    #expect(params.1 == "New Name")
  }

  @Test
  func attemptVerificationUsesPasskeyServiceAttemptVerification() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockPasskeyService(attemptVerification: { passkeyId, credential in
      captured.setValue((passkeyId, credential))
      return .mock
    })

    configureService(service)

    _ = try await passkey.attemptVerification(credential: "mock_credential")

    let params = try #require(captured.value)
    #expect(params.0 == passkey.id)
    #expect(params.1 == "mock_credential")
  }

  @Test
  func deleteUsesPasskeyServiceDelete() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPasskeyService(delete: { passkeyId in
      captured.setValue(passkeyId)
      return .mock
    })

    configureService(service)

    _ = try await passkey.delete()

    #expect(captured.value == passkey.id)
  }

  @Test
  func relyingPartyIdentifierReadsRegistrationNonce() throws {
    let passkey = passkey(withNonce: #"{"rp":{"id":"example.com"},"challenge":"Y2hhbGxlbmdl"}"#)

    #expect(passkey.relyingPartyIdentifier == "example.com")
  }

  private func passkey(withNonce nonce: String) -> Passkey {
    Passkey(
      id: "passkey_test",
      name: "Test passkey",
      verification: Verification(
        status: .unverified,
        strategy: .passkey,
        nonce: nonce
      ),
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
  }
}
