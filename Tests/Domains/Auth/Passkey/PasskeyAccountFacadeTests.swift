@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct PasskeyAccountFacadeTests {
  private let fixture = ClerkTestFixture()

  private func makeClerk(_ service: MockPasskeyService) throws -> Clerk {
    try fixture.makeClerk(
      apiClient: createMockAPIClient(),
      passkeyService: service,
      environment: .mock
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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.update(passkey, name: "New Name")

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.attemptVerification("mock_credential", for: passkey)

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.delete(passkey)

    #expect(captured.value == passkey.id)
  }
}
