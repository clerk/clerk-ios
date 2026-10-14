@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct PhoneNumberTests {
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
  func deleteSendsPhoneNumberId() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    transport.stub(PhoneNumberAPI.delete(phoneNumberId: FakeTransport.anyPathSegment)) { call in
      captured.setValue(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await phoneNumber.delete()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func sendCodeSendsPhoneNumberId() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    transport.stub(PhoneNumberAPI.prepareVerification(phoneNumberId: FakeTransport.anyPathSegment)) { call in
      captured.setValue(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await phoneNumber.sendCode()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func verifyCodeSendsPhoneNumberIdAndCode() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(PhoneNumberAPI.attemptVerification(phoneNumberId: FakeTransport.anyPathSegment, code: "")) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await phoneNumber.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1?["code"]?.stringValue == "123456")
  }

  @Test
  func makeDefaultSecondFactorSendsPhoneNumberId() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(PhoneNumberAPI.makeDefaultSecondFactor(phoneNumberId: FakeTransport.anyPathSegment)) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await phoneNumber.makeDefaultSecondFactor()

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1?["default_second_factor"]?.boolValue == true)
  }

  @Test
  func setReservedForSecondFactorSendsPhoneNumberIdAndReserved() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stub(PhoneNumberAPI.setReservedForSecondFactor(phoneNumberId: FakeTransport.anyPathSegment, reserved: true)) { call in
      captured.setValue((String(call.path.split(separator: "/")[3]), call.body))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await phoneNumber.setReservedForSecondFactor(reserved: true)

    let params = try #require(captured.value)
    #expect(params.0 == phoneNumber.id)
    #expect(params.1?["reserved_for_second_factor"]?.boolValue == true)
  }
}
