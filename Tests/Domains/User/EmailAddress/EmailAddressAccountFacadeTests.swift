@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct EmailAddressAccountFacadeTests {
  private let fixture = ClerkTestFixture()

  private func makeClerk(_ service: MockEmailAddressService) throws -> Clerk {
    try fixture.makeClerk(
      apiClient: createMockAPIClient(),
      emailAddressService: service,
      environment: .mock
    )
  }

  @Test
  func sendCodeUsesEmailAddressServicePrepareVerification() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<(String, EmailAddress.PrepareStrategy)?>(nil)
    let service = MockEmailAddressService(prepareVerification: { id, strategy, _ in
      captured.setValue((id, strategy))
      return .mock
    })
    let clerk = try makeClerk(service)

    _ = try await clerk.account.sendCode(to: emailAddress)

    let params = try #require(captured.value)
    #expect(params.0 == emailAddress.id)
    #expect(params.1 == .emailCode)
  }

  @Test
  func verifyCodeUsesEmailAddressServiceAttemptVerification() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<(String, EmailAddress.AttemptStrategy)?>(nil)
    let service = MockEmailAddressService(attemptVerification: { id, strategy in
      captured.setValue((id, strategy))
      return .mock
    })
    let clerk = try makeClerk(service)

    _ = try await clerk.account.verifyCode("123456", for: emailAddress)

    let params = try #require(captured.value)
    #expect(params.0 == emailAddress.id)
    switch params.1 {
    case .emailCode(let code):
      #expect(code == "123456")
    }
  }

  @Test
  func destroyUsesEmailAddressServiceDestroy() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockEmailAddressService(destroy: { id in
      captured.setValue(id)
      return .mock
    })
    let clerk = try makeClerk(service)

    _ = try await clerk.account.destroy(emailAddress)

    #expect(captured.value == emailAddress.id)
  }
}
