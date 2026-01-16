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
  func deleteUsesPhoneNumberServiceDelete() async throws {
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
  func sendCodeUsesPhoneNumberServicePrepareVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(prepareVerification: { phoneNumberId in
      captured.setValue(phoneNumberId)
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.sendCode()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func verifyCodeUsesPhoneNumberServiceAttemptVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockPhoneNumberService(attemptVerification: { phoneNumberId, code in
      captured.setValue((phoneNumberId, code))
      return .mock
    })

    configureService(service)

    _ = try await phoneNumber.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1 == "123456")
  }

  @Test
  func makeDefaultSecondFactorUsesPhoneNumberServiceMakeDefaultSecondFactor() async throws {
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
  func setReservedForSecondFactorUsesPhoneNumberServiceSetReservedForSecondFactor() async throws {
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
