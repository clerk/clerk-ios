@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EmailAddressTests {
  private let transport = FakeTransport()

  init() {
    configureClerkForTesting()
    useTransport(transport)
  }

  private func useTransport(_ transport: FakeTransport) {
    let apiClient = createMockAPIClient()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      transport: transport
    )
  }

  @Test
  func createEmailAddressPostsTheNewAddress() async throws {
    let fixture = EmailAddress.mock
    transport.stub(EmailAddressAPI.create(email: "new@example.com"), returning: ClientResponse(response: fixture, client: nil))

    let created = try await User.mock.createEmailAddress("new@example.com")

    #expect(created == fixture)
    let call = try #require(transport.calls.first)
    #expect(transport.calls.count == 1)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/email_addresses")
    #expect(call.body?["email_address"]?.stringValue == "new@example.com")
    #expect(call.isScopedToActiveSession)
  }

  @Test
  func sendCodePreparesAnEmailCodeVerification() async throws {
    let emailAddress = EmailAddress.mock
    transport.stub(EmailAddressAPI.prepareVerification(emailAddressId: emailAddress.id, strategy: .emailCode), returning: ClientResponse(response: emailAddress, client: nil))

    let prepared = try await emailAddress.sendCode()

    #expect(prepared == emailAddress)
    let call = try #require(transport.calls.first)
    #expect(transport.calls.count == 1)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/email_addresses/\(emailAddress.id)/prepare_verification")
    #expect(call.body?["strategy"]?.stringValue == "email_code")
    #expect(call.isScopedToActiveSession)
  }

  @Test
  func verifyCodeAttemptsVerificationWithTheCode() async throws {
    let emailAddress = EmailAddress.mock
    transport.stub(EmailAddressAPI.attemptVerification(emailAddressId: emailAddress.id, strategy: .emailCode(code: "123456")), returning: ClientResponse(response: emailAddress, client: nil))

    let verified = try await emailAddress.verifyCode("123456")

    #expect(verified == emailAddress)
    let call = try #require(transport.calls.first)
    #expect(transport.calls.count == 1)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/email_addresses/\(emailAddress.id)/attempt_verification")
    #expect(call.body?["code"]?.stringValue == "123456")
    #expect(call.isScopedToActiveSession)
  }

  @Test
  func destroyDeletesTheEmailAddress() async throws {
    let emailAddress = EmailAddress.mock
    transport.stub(EmailAddressAPI.destroy(emailAddressId: emailAddress.id), returning: ClientResponse(response: .mock, client: nil))

    let deleted = try await emailAddress.destroy()

    #expect(deleted.id == DeletedObject.mock.id)
    let call = try #require(transport.calls.first)
    #expect(transport.calls.count == 1)
    #expect(call.method == .delete)
    #expect(call.path == "/v1/me/email_addresses/\(emailAddress.id)")
    #expect(call.body == nil)
    #expect(call.isScopedToActiveSession)
  }

  @Test
  func unstubbedRequestThrows() async throws {
    await #expect(throws: FakeTransport.Failure.self) {
      try await EmailAddress.mock.sendCode()
    }
    #expect(transport.calls.count == 1)
  }

  @Test
  func mockDefaultsAnswerEveryEmailAddressEndpoint() async throws {
    useTransport(.mockDefaults())
    let emailAddress = EmailAddress.mock

    #expect(try await User.mock.createEmailAddress("preview@example.com").id == emailAddress.id)
    #expect(try await emailAddress.sendCode().id == emailAddress.id)
    #expect(try await emailAddress.verifyCode("424242").id == emailAddress.id)
    #expect(try await emailAddress.destroy().id == DeletedObject.mock.id)
  }
}
