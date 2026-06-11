@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func revokeUsesSessionServiceRevoke() async throws {
    let session = Session.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockSessionService(revoke: { sessionId in
      captured.setValue(sessionId)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await session.revoke()

    #expect(captured.value == session.id)
  }

  @Test
  func taskKeyParsesSetupMfa() {
    let task = Session.Task(key: "setup-mfa")
    #expect(task == .setupMfa)
  }

  @Test
  func taskKeyParsesResetPassword() {
    let task = Session.Task(key: "reset-password")
    #expect(task == .resetPassword)
  }

  @Test
  func taskKeyParsesUnknownTask() {
    let task = Session.Task(key: "another-task")
    #expect(task == .unknown("another-task"))
  }

  @Test
  func sessionVerificationDecodesSupportedFactorMetadata() throws {
    let json = """
    {
      "status": "needs_first_factor",
      "level": "first_factor",
      "supported_first_factors": [
        {
          "strategy": "enterprise_sso",
          "enterprise_connection_id": "econn_123",
          "enterprise_connection_name": "Acme"
        }
      ],
      "supported_second_factors": [
        {
          "strategy": "phone_code",
          "phone_number_id": "idn_123",
          "safe_identifier": "+15555550123",
          "primary": true,
          "default": true
        }
      ]
    }
    """

    let data = try #require(json.data(using: .utf8))
    let verification = try JSONDecoder.clerkDecoder.decode(SessionVerification.self, from: data)
    let firstFactor = try #require(verification.supportedFirstFactors?.first)
    let secondFactor = try #require(verification.supportedSecondFactors?.first)

    #expect(firstFactor.strategy == .enterpriseSSO)
    #expect(firstFactor.enterpriseConnectionId == "econn_123")
    #expect(firstFactor.enterpriseConnectionName == "Acme")
    #expect(secondFactor.strategy == .phoneCode)
    #expect(secondFactor.phoneNumberId == "idn_123")
    #expect(secondFactor.safeIdentifier == "+15555550123")
    #expect(secondFactor.primary == true)
    #expect(secondFactor.default == true)
  }

  @Test
  func startVerificationForwardsLevelToService() async throws {
    let session = Session.mock
    let capturedSessionId = LockIsolated<String?>(nil)
    let capturedLevel = LockIsolated<SessionVerification.Level?>(nil)
    let service = MockSessionService(startVerification: { sessionId, params in
      capturedSessionId.setValue(sessionId)
      capturedLevel.setValue(params.level)
      return .mockNeedsFirstFactor
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.startVerification(level: .firstFactor)

    #expect(capturedSessionId.value == session.id)
    #expect(capturedLevel.value == .firstFactor)
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func sendEmailCodeCallsPrepareFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedEmailAddressId = LockIsolated<String?>(nil)
    let service = MockSessionService(prepareFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedEmailAddressId.setValue(params.emailAddressId)
      return .mockNeedsFirstFactor
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.sendEmailCode(emailAddressId: "idn_email")

    #expect(capturedStrategy.value == .emailCode)
    #expect(capturedEmailAddressId.value == "idn_email")
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func sendPhoneCodeCallsPrepareFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedPhoneNumberId = LockIsolated<String?>(nil)
    let service = MockSessionService(prepareFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedPhoneNumberId.setValue(params.phoneNumberId)
      return .mockNeedsFirstFactor
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.sendPhoneCode(phoneNumberId: "idn_phone")

    #expect(capturedStrategy.value == .phoneCode)
    #expect(capturedPhoneNumberId.value == "idn_phone")
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func verifyWithEmailCodeCallsAttemptFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedCode = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedCode.setValue(params.code)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithEmailCode(code: "123456")

    #expect(capturedStrategy.value == .emailCode)
    #expect(capturedCode.value == "123456")
    #expect(verification.status == .complete)
  }

  @Test
  func verifyWithPhoneCodeCallsAttemptFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedCode = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedCode.setValue(params.code)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithPhoneCode(code: "123456")

    #expect(capturedStrategy.value == .phoneCode)
    #expect(capturedCode.value == "123456")
    #expect(verification.status == .complete)
  }

  @Test
  func verifyWithPasswordCallsAttemptFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedPassword = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedPassword.setValue(params.password)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithPassword("hunter2")

    #expect(capturedStrategy.value == .password)
    #expect(capturedPassword.value == "hunter2")
    #expect(verification.status == .complete)
  }

  @Test
  func startEnterpriseSSOCallsPrepareFirstFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedEmailAddressId = LockIsolated<String?>(nil)
    let capturedEnterpriseConnectionId = LockIsolated<String?>(nil)
    let capturedRedirectUrl = LockIsolated<String?>(nil)
    let service = MockSessionService(prepareFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedEmailAddressId.setValue(params.emailAddressId)
      capturedEnterpriseConnectionId.setValue(params.enterpriseConnectionId)
      capturedRedirectUrl.setValue(params.redirectUrl)
      return .mockNeedsFirstFactor
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.startEnterpriseSSO(
      emailAddressId: "idn_email",
      enterpriseConnectionId: "econn_123",
      redirectUrl: "myapp://callback"
    )

    #expect(capturedStrategy.value == .enterpriseSSO)
    #expect(capturedEmailAddressId.value == "idn_email")
    #expect(capturedEnterpriseConnectionId.value == "econn_123")
    #expect(capturedRedirectUrl.value == "myapp://callback")
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func startEnterpriseSSOUsesDefaultRedirectUrl() async throws {
    let defaultRedirectUrl = "myapp://default-callback"
    let options = Clerk.Options(
      redirectConfig: .init(
        redirectUrl: defaultRedirectUrl,
        callbackUrlScheme: "myapp"
      )
    )

    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedEmailAddressId = LockIsolated<String?>(nil)
    let capturedEnterpriseConnectionId = LockIsolated<String?>(nil)
    let capturedRedirectUrl = LockIsolated<String?>(nil)
    let service = MockSessionService(prepareFirstFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedEmailAddressId.setValue(params.emailAddressId)
      capturedEnterpriseConnectionId.setValue(params.enterpriseConnectionId)
      capturedRedirectUrl.setValue(params.redirectUrl)
      return .mockNeedsFirstFactor
    })

    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: options
    )
    Clerk.shared.dependencies = dependencies
    defer { configureClerkForTesting() }

    let verification = try await session.startEnterpriseSSO(
      emailAddressId: "idn_email",
      enterpriseConnectionId: "econn_123"
    )

    #expect(capturedStrategy.value == .enterpriseSSO)
    #expect(capturedEmailAddressId.value == "idn_email")
    #expect(capturedEnterpriseConnectionId.value == "econn_123")
    #expect(capturedRedirectUrl.value == defaultRedirectUrl)
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func sendMfaPhoneCodeCallsPrepareSecondFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedPhoneNumberId = LockIsolated<String?>(nil)
    let service = MockSessionService(prepareSecondFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedPhoneNumberId.setValue(params.phoneNumberId)
      return .mockNeedsSecondFactor
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.sendMfaPhoneCode(phoneNumberId: "idn_phone")

    #expect(capturedStrategy.value == .phoneCode)
    #expect(capturedPhoneNumberId.value == "idn_phone")
    #expect(verification.status == .needsSecondFactor)
  }

  @Test
  func verifyWithMfaPhoneCodeCallsAttemptSecondFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedCode = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptSecondFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedCode.setValue(params.code)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithMfaPhoneCode(code: "123456")

    #expect(capturedStrategy.value == .phoneCode)
    #expect(capturedCode.value == "123456")
    #expect(verification.status == .complete)
  }

  @Test
  func verifyWithTOTPCallsAttemptSecondFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedCode = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptSecondFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedCode.setValue(params.code)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithTOTP(code: "123456")

    #expect(capturedStrategy.value == .totp)
    #expect(capturedCode.value == "123456")
    #expect(verification.status == .complete)
  }

  @Test
  func verifyWithBackupCodeCallsAttemptSecondFactor() async throws {
    let session = Session.mock
    let capturedStrategy = LockIsolated<FactorStrategy?>(nil)
    let capturedCode = LockIsolated<String?>(nil)
    let service = MockSessionService(attemptSecondFactorVerification: { _, params in
      capturedStrategy.setValue(params.strategy)
      capturedCode.setValue(params.code)
      return .mockComplete
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let verification = try await session.verifyWithBackupCode(code: "abcdef")

    #expect(capturedStrategy.value == .backupCode)
    #expect(capturedCode.value == "abcdef")
    #expect(verification.status == .complete)
  }
}
