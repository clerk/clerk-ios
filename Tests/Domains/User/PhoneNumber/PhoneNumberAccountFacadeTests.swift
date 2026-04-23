@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct PhoneNumberAccountFacadeTests {
  private let fixture = ClerkTestFixture()

  private func makeClerk(_ service: MockPhoneNumberService) throws -> Clerk {
    try fixture.makeClerk(
      apiClient: createMockAPIClient(),
      phoneNumberService: service,
      environment: .mock
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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.delete(phoneNumber)

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.sendCode(to: phoneNumber)

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.verifyCode("123456", for: phoneNumber)

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.makeDefaultSecondFactor(for: phoneNumber)

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
    let clerk = try makeClerk(service)

    _ = try await clerk.account.setReservedForSecondFactor(true, for: phoneNumber)

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1 == true)
  }
}
