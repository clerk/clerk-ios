import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct PhoneNumberTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockPhoneNumberService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      phoneNumberService: service
    )
  }

  @Test
  func createUsesService() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(create: { phoneNumber in
      captured.setValue(phoneNumber)
      return .mock
    })

    configureService(service)

    _ = try await PhoneNumber.create("+1234567890")

    #expect(captured.value == "+1234567890")
  }

  @Test
  func deleteUsesService() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(delete: { phoneNumberId in
      captured.setValue(phoneNumberId)
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.delete()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func prepareVerificationUsesService() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(prepareVerification: { phoneNumberId in
      captured.setValue(phoneNumberId)
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.prepareVerification()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func attemptVerificationUsesService() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockPhoneNumberService(attemptVerification: { phoneNumberId, code in
      captured.setValue((phoneNumberId, code))
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.attemptVerification(code: "123456")

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1 == "123456")
  }

  @Test
  func makeDefaultSecondFactorUsesService() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(makeDefaultSecondFactor: { phoneNumberId in
      captured.setValue(phoneNumberId)
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.makeDefaultSecondFactor()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func setReservedForSecondFactorUsesService() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, Bool)?>(nil)
    let service = MockPhoneNumberService(setReservedForSecondFactor: { phoneNumberId, reserved in
      captured.setValue((phoneNumberId, reserved))
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.setReservedForSecondFactor(reserved: true)

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1 == true)
  }
}
