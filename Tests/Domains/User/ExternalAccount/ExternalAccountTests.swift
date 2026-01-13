import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ExternalAccountTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockExternalAccountService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      externalAccountService: service
    )
  }

  @Test
  func destroyUsesService() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let captured = LockIsolated<String?>(nil)
    let service = MockExternalAccountService(destroy: { externalAccountId in
      captured.setValue(externalAccountId)
      return .mock
    })

    configureService(service)

    _ = try await externalAccount.destroy()

    #expect(captured.value == externalAccount.id)
  }
}
