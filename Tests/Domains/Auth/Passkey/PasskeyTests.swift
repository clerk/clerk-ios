@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct PasskeyTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
  }

  private func configureTransport() {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  @Test
  func updateSendsPasskeyIdAndName() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(PasskeyAPI.update(passkeyId: FakeTransport.anyPathSegment, name: "")) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await passkey.update(name: "New Name")

    let params = try #require(captured.value)
    #expect(params.0 == passkey.id)
    #expect(params.1?["name"]?.stringValue == "New Name")
  }

  @Test
  func attemptVerificationSendsPasskeyIdAndCredential() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(PasskeyAPI.attemptVerification(passkeyId: FakeTransport.anyPathSegment, credential: "")) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await passkey.attemptVerification(credential: "mock_credential")

    let params = try #require(captured.value)
    #expect(params.0 == passkey.id)
    #expect(params.1?["public_key_credential"]?.stringValue == "mock_credential")
  }

  @Test
  func deleteSendsPasskeyId() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<String?>(nil)
    transport.stub(PasskeyAPI.delete(passkeyId: FakeTransport.anyPathSegment)) { call in
      captured.setValue(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await passkey.delete()

    #expect(captured.value == passkey.id)
  }

  @Test
  func relyingPartyIdentifierReadsRegistrationNonce() {
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
