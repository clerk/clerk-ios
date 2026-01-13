import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct EmailAddressTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockEmailAddressService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      emailAddressService: service
    )
  }

  @Test
  func createUsesService() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockEmailAddressService(create: { email in
      captured.setValue(email)
      return .mock
    })

    configureService(service)

    _ = try await EmailAddress.create("test@example.com")

    #expect(captured.value == "test@example.com")
  }

  @Test
  func prepareVerificationUsesService() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<(String, EmailAddress.PrepareStrategy)?>(nil)
    let service = MockEmailAddressService(prepareVerification: { id, strategy in
      captured.setValue((id, strategy))
      return .mock
    })

    configureService(service)

    _ = try await emailAddress.prepareVerification(strategy: .emailCode)

    let params = try #require(captured.value)
    #expect(params.0 == emailAddress.id)
    #expect(params.1 == .emailCode)
  }

  @Test
  func attemptVerificationUsesService() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<(String, EmailAddress.AttemptStrategy)?>(nil)
    let service = MockEmailAddressService(attemptVerification: { id, strategy in
      captured.setValue((id, strategy))
      return .mock
    })

    configureService(service)

    _ = try await emailAddress.attemptVerification(strategy: .emailCode(code: "123456"))

    let params = try #require(captured.value)
    #expect(params.0 == emailAddress.id)
    switch params.1 {
    case .emailCode(let code):
      #expect(code == "123456")
    }
  }

  @Test
  func destroyUsesService() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockEmailAddressService(destroy: { id in
      captured.setValue(id)
      return .mock
    })

    configureService(service)

    _ = try await emailAddress.destroy()

    #expect(captured.value == emailAddress.id)
  }
}
