@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct ExternalAccountAccountFacadeTests {
  private let fixture = ClerkTestFixture()

  private func makeClerk(_ service: MockExternalAccountService) throws -> Clerk {
    try fixture.makeClerk(
      apiClient: createMockAPIClient(),
      externalAccountService: service,
      environment: .mock
    )
  }

  @Test
  func destroyUsesExternalAccountServiceDestroy() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let captured = LockIsolated<String?>(nil)
    let service = MockExternalAccountService(destroy: { externalAccountId, _ in
      captured.setValue(externalAccountId)
      return .mock
    })
    let clerk = try makeClerk(service)

    _ = try await clerk.account.destroy(externalAccount)

    #expect(captured.value == externalAccount.id)
  }
}
