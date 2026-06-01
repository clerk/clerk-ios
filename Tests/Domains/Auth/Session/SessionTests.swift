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
