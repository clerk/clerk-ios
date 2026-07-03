@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct TrustedDevicesTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func listUsesTrustedDeviceService() async throws {
    let called = LockIsolated(false)
    let service = MockTrustedDeviceService(list: {
      called.setValue(true)
      return [.mock]
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      trustedDeviceService: service
    )

    let trustedDevices = try await Clerk.shared.trustedDevices.list()

    #expect(called.value == true)
    #expect(trustedDevices == [.mock])
  }

  @Test
  func revokeUsesTrustedDeviceService() async throws {
    let capturedTrustedDeviceId = LockIsolated<String?>(nil)
    let service = MockTrustedDeviceService(revoke: { trustedDeviceId in
      capturedTrustedDeviceId.setValue(trustedDeviceId)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      trustedDeviceService: service
    )

    let trustedDevice = try await Clerk.shared.trustedDevices.revoke(id: "tdc_123")

    #expect(capturedTrustedDeviceId.value == "tdc_123")
    #expect(trustedDevice == .mock)
  }

  @Test
  func availabilityReturnsAvailableLocalCredentialWithoutActiveSession() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeTrustedDevicesWithLocalCredential()

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
  }

  @Test
  func availabilityReturnsAvailableWithMultipleLocalCredentials() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = makeTrustedDevices()
    try setup.credentialStore.save(localCredential(
      id: "tdc_old",
      localKeyId: "tdlk_old",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_new",
      localKeyId: "tdlk_new",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func availabilityReconcilesServerCredentialWhenSessionIsActive() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(list: { [.mock] })
    )

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func localAvailabilityDoesNotReconcileServerCredentialWhenSessionIsActive() throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(list: {
        Issue.record("Local availability should not fetch trusted devices.")
        return []
      })
    )

    let availability = try setup.trustedDevices.localAvailability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleReturnsValidForServerCredential() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedTrustedDeviceId = LockIsolated<String?>(nil)
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(validateSignInCredential: { trustedDeviceId in
        capturedTrustedDeviceId.setValue(trustedDeviceId)
        return .init(valid: true)
      })
    )

    let result = await setup.trustedDevices.validateLocalCredentialIfPossible()

    #expect(result == .valid)
    #expect(capturedTrustedDeviceId.value == "tdc_123")
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleDeletesMissingServerCredential() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(validateSignInCredential: { _ in
        throw missingTrustedDeviceCredentialError()
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let result = await setup.trustedDevices.validateLocalCredentialIfPossible()

    #expect(result == .invalid(.serverCredentialMissing))
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
  }

  @Test
  func validateLocalCredentialIfPossibleKeepsCredentialForTransientError() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(validateSignInCredential: { _ in
        throw URLError(.timedOut)
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let result = await setup.trustedDevices.validateLocalCredentialIfPossible()

    #expect(result == .inconclusive)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleIsInconclusiveWithoutCachedClient() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = nil
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(validateSignInCredential: { _ in
        Issue.record("Validation should not run without a cached client.")
        return .init(valid: true)
      })
    )

    let result = await setup.trustedDevices.validateLocalCredentialIfPossible()

    #expect(result == .inconclusive)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func availabilitySkipsStaleNewerCredentialWhenSignedIn() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(list: {
        [trustedDevice(id: "tdc_old", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_old",
      localKeyId: "tdlk_old",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_new",
      localKeyId: "tdlk_new",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == true)
    #expect(deletedLocalKeyIds.value == ["tdlk_new"])
    #expect(try setup.credentialStore.credential(id: "tdc_new") == nil)
  }

  @Test
  func availabilityDoesNotReconcileServerCredentialWhenSessionIsExpired() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = Client(
      id: "client_expired",
      sessions: [.mockExpired],
      lastActiveSessionId: Session.mockExpired.id,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(list: {
        Issue.record("Expired sessions should not trigger authenticated trusted-device list.")
        return []
      })
    )

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func availabilityReturnsFeatureDisabledWhenNativeSettingIsOff() async throws {
    Clerk.shared.environment = .mock
    Clerk.shared.client = .mockSignedOut
    let setup = try makeTrustedDevicesWithLocalCredential()

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .nativeAPIDisabled)
  }

  @Test
  func availabilityDeletesMetadataWhenLocalKeyIsMissing() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeTrustedDevicesWithLocalCredential(
      keyManager: MockTrustedDeviceKeyManager(hasKey: { _ in false })
    )

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .localKeyMissing)
    #expect(try setup.credentialStore.all().isEmpty)
  }

  @Test
  func availabilityDeletesMetadataWhenServerCredentialIsMissing() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(list: { [] }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .serverCredentialMissing)
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.all().isEmpty)
  }

  @Test
  func availabilityIgnoresCredentialFromDifferentAppIdentifierBeforeCheckingKeys() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(keyManager: MockTrustedDeviceKeyManager(hasKey: { localKeyId in
      checkedLocalKeyIds.withValue { $0.append(localKeyId) }
      return false
    }))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
    #expect(checkedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func signInUsesCurrentAppCredentialWhenSharedKeychainContainsNewerCredential() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeTrustedDevices(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockTrustedDeviceChallenge
      },
      attemptFirstFactor: { _, _ in .mockTrustedDeviceComplete }
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_app",
      localKeyId: "tdlk_current_app",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    _ = try await setup.trustedDevices.signIn()

    #expect(capturedCreateParams.value?.trustedDeviceId == "tdc_current_app")
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func availabilityDoesNotDeleteCredentialOwnedByDifferentUserWhenSignedIn() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let listWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(list: {
        listWasCalled.setValue(true)
        return []
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_user",
      localKeyId: "tdlk_other_user",
      userID: User.mock2.id,
      identifierHint: "sam@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.trustedDevices.availability(identifierHint: "sam@example.com")

    #expect(availability.isAvailable)
    #expect(listWasCalled.value == false)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func availabilityDoesNotDeleteNewestCredentialOwnedByDifferentUserWhenIdentifierHintIsNil() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let listWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(list: {
        listWasCalled.setValue(true)
        return [trustedDevice(id: "tdc_active_user", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_active_user",
      localKeyId: "tdlk_active_user",
      userID: User.mock.id,
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_user",
      localKeyId: "tdlk_other_user",
      userID: User.mock2.id,
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable)
    #expect(listWasCalled.value == false)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_active_user") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func availabilityUsesUserIDWhenIdentifierHintChanged() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(list: {
        [trustedDevice(id: "tdc_current_user", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.trustedDevices.currentUserAvailability()

    #expect(availability.isAvailable)
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") != nil)
  }

  @Test
  func localAvailabilityUsesUserIDWhenIdentifierHintChanged() throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let setup = makeTrustedDevices()
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try setup.trustedDevices.currentUserLocalAvailability()

    #expect(availability.isAvailable)
  }

  @Test
  func enrollCreatesKeyPreparesChallengeAttemptsAndPersistsMetadata() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let preparedParams = LockIsolated<TrustedDevice.PrepareEnrollmentParams?>(nil)
    let attemptedParams = LockIsolated<TrustedDevice.AttemptEnrollmentParams?>(nil)
    let trustedDeviceService = MockTrustedDeviceService(
      prepareEnrollment: { params in
        preparedParams.setValue(params)
        return .mock
      },
      attemptEnrollment: { params in
        attemptedParams.setValue(params)
        return .mock
      }
    )
    let keyManager = MockTrustedDeviceKeyManager(
      createKeyWithPolicy: { policy in
        #expect(policy == .biometryOrDevicePasscode)
        return .init(
          localKeyId: TrustedDeviceLocalKey.mock.localKeyId,
          publicKeyJWK: TrustedDeviceLocalKey.mock.publicKeyJWK,
          policy: policy
        )
      },
      sign: { clientData, localKeyId, localizedReason in
        #expect(clientData == TrustedDeviceChallenge.mock.clientData)
        #expect(localKeyId == TrustedDeviceLocalKey.mock.localKeyId)
        #expect(localizedReason == "Set up Face ID for future sign-ins.")
        return .init(clientData: clientData, signature: "enrollment_signature")
      }
    )
    let setup = makeTrustedDevices(
      trustedDeviceService: trustedDeviceService,
      keyManager: keyManager
    )

    let trustedDevice = try await setup.trustedDevices.enroll(
      name: "Sean's iPhone",
      identifierHint: "  Sean@Example.COM  ",
      reason: "Set up Face ID for future sign-ins.",
      policy: .biometryOrDevicePasscode
    )
    let localCredential = try #require(try setup.credentialStore.credential(id: "tdc_123"))

    #expect(trustedDevice == .mock)
    #expect(preparedParams.value?.appIdentifier == "com.clerk.example")
    #expect(preparedParams.value?.name == "Sean's iPhone")
    #expect(preparedParams.value?.publicKeyJWK == TrustedDeviceLocalKey.mock.publicKeyJWK)
    #expect(attemptedParams.value?.signature == "enrollment_signature")
    #expect(localCredential.localKeyId == TrustedDeviceLocalKey.mock.localKeyId)
    #expect(localCredential.userID == User.mock.id)
    #expect(localCredential.identifierHint == "sean@example.com")
    #expect(localCredential.policy == .biometryOrDevicePasscode)
  }

  @Test
  func enrollReplacesOtherCurrentAppCredentialsAfterSuccessfulEnrollment() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let revokedTrustedDeviceIds = LockIsolated<[String]>([])
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(revoke: { trustedDeviceId in
        revokedTrustedDeviceIds.withValue { $0.append(trustedDeviceId) }
        return trustedDevice(id: trustedDeviceId, createdAt: Date(timeIntervalSinceReferenceDate: 10))
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_user",
      localKeyId: "tdlk_other_user",
      userID: User.mock2.id,
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSinceReferenceDate: 30)
    ))

    _ = try await setup.trustedDevices.enroll()

    #expect(revokedTrustedDeviceIds.value.isEmpty)
    #expect(deletedLocalKeyIds.value == ["tdlk_current_user", "tdlk_other_user"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func enrollKeepsExistingCredentialsWhenEnrollmentFails() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(
        prepareEnrollment: { _ in .mock },
        attemptEnrollment: { _ in throw ClerkClientError(message: "Attempt failed") }
      ),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_existing",
      localKeyId: "tdlk_existing",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    do {
      _ = try await setup.trustedDevices.enroll()
      Issue.record("Expected enrollment to fail.")
    } catch {
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.credential(id: "tdc_existing") != nil)
    }
  }

  @Test
  func enrollDoesNotCallBackendRevokeForReplacedLocalCredentials() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(revoke: { _ in
        throw ClerkClientError(message: "Revoke failed")
      }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_existing",
      localKeyId: "tdlk_existing",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    _ = try await setup.trustedDevices.enroll()

    #expect(deletedLocalKeyIds.value == ["tdlk_existing"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_existing") == nil)
  }

  @Test
  func enrollAllowsPendingSession() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    var pendingSession = Session.mock
    pendingSession.id = "sess_pending_tasks"
    pendingSession.status = .pending
    pendingSession.tasks = [.setupMfa]
    Clerk.shared.client = Client(
      id: "client_pending_tasks",
      sessions: [pendingSession],
      lastActiveSessionId: pendingSession.id,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let prepareWasCalled = LockIsolated(false)
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(
        prepareEnrollment: { _ in
          prepareWasCalled.setValue(true)
          return .mock
        }
      )
    )

    _ = try await setup.trustedDevices.enroll()

    #expect(prepareWasCalled.value)
  }

  @Test
  func enrollDefaultsToBiometryOrDevicePasscodePolicy() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let createdKeyPolicies = LockIsolated<[TrustedDevicePolicy]>([])
    let setup = makeTrustedDevices(
      keyManager: MockTrustedDeviceKeyManager(
        createKeyWithPolicy: { policy in
          createdKeyPolicies.withValue { $0.append(policy) }
          return .init(
            localKeyId: TrustedDeviceLocalKey.mock.localKeyId,
            publicKeyJWK: TrustedDeviceLocalKey.mock.publicKeyJWK,
            policy: policy
          )
        }
      )
    )

    _ = try await setup.trustedDevices.enroll()
    let localCredential = try #require(try setup.credentialStore.credential(id: TrustedDevice.mock.id))

    #expect(createdKeyPolicies.value == [.biometryOrDevicePasscode])
    #expect(localCredential.policy == .biometryOrDevicePasscode)
  }

  @Test
  func enrollDeletesGeneratedKeyWhenAttemptFails() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let trustedDeviceService = MockTrustedDeviceService(
      prepareEnrollment: { _ in .mock },
      attemptEnrollment: { _ in throw ClerkClientError(message: "Attempt failed") }
    )
    let keyManager = MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })
    let setup = makeTrustedDevices(
      trustedDeviceService: trustedDeviceService,
      keyManager: keyManager
    )

    do {
      _ = try await setup.trustedDevices.enroll()
      Issue.record("Expected enrollment to fail.")
    } catch {
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.all().isEmpty)
    }
  }

  @Test
  func enrollRequiresActiveOrPendingSession() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = makeTrustedDevices()

    do {
      _ = try await setup.trustedDevices.enroll()
      Issue.record("Expected enrollment to require an active or pending session.")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("active or pending Clerk session") == true)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func revokeDeletesLocalCredentialAfterServerRevoke() async throws {
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(revoke: { _ in .mock }),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let trustedDevice = try await setup.trustedDevices.revoke(id: "tdc_123")

    #expect(trustedDevice == .mock)
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
  }

  @Test
  func revokeCurrentDeviceCredentialUsesUserIDWhenIdentifierHintChanged() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let revokedTrustedDeviceIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(
        list: {
          [
            trustedDevice(id: "tdc_current_user", createdAt: Date(timeIntervalSinceReferenceDate: 10)),
            trustedDevice(id: "tdc_other_user", createdAt: Date(timeIntervalSinceReferenceDate: 20)),
          ]
        },
        revoke: { trustedDeviceId in
          revokedTrustedDeviceIds.withValue { $0.append(trustedDeviceId) }
          return trustedDevice(id: trustedDeviceId, createdAt: Date(timeIntervalSinceReferenceDate: 10))
        }
      )
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_user",
      localKeyId: "tdlk_other_user",
      userID: User.mock2.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    let revokedTrustedDevice = try await setup.trustedDevices.revokeCurrentDeviceCredential()

    #expect(revokedTrustedDevice?.id == "tdc_current_user")
    #expect(revokedTrustedDeviceIds.value == ["tdc_current_user"])
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func revokeCurrentDeviceCredentialReturnsNilWhenNoLocalCredentialIsAvailable() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let revokeWasCalled = LockIsolated(false)
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(revoke: { _ in
        revokeWasCalled.setValue(true)
        return .mock
      })
    )

    let trustedDevice = try await setup.trustedDevices.revokeCurrentDeviceCredential()

    #expect(trustedDevice == nil)
    #expect(revokeWasCalled.value == false)
  }

  @Test
  func revokeCurrentDeviceCredentialAllowsPendingSession() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    var pendingSession = Session.mock
    pendingSession.id = "sess_pending_tasks"
    pendingSession.status = .pending
    pendingSession.tasks = [.setupMfa]
    Clerk.shared.client = Client(
      id: "client_pending_tasks",
      sessions: [pendingSession],
      lastActiveSessionId: pendingSession.id,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let revokedTrustedDeviceIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      trustedDeviceService: MockTrustedDeviceService(revoke: { trustedDeviceId in
        revokedTrustedDeviceIds.withValue { $0.append(trustedDeviceId) }
        return .mock
      })
    )

    _ = try await setup.trustedDevices.revokeCurrentDeviceCredential()

    #expect(revokedTrustedDeviceIds.value == ["tdc_123"])
  }

  @Test
  func revokeCurrentDeviceCredentialRequiresActiveOrPendingSession() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeTrustedDevicesWithLocalCredential()

    do {
      _ = try await setup.trustedDevices.revokeCurrentDeviceCredential()
      Issue.record("Expected revoking a current-device credential to require an active or pending session.")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("active or pending Clerk session") == true)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func forgetLocalCredentialsDeletesDeletedUserIDAfterCurrentUserIsCleared() throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    }))
    try setup.credentialStore.save(localCredential(
      id: "tdc_deleted",
      localKeyId: "tdlk_deleted",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      userID: User.mock.id,
      appIdentifier: "com.clerk.other",
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let deletedCount = try setup.trustedDevices.forgetLocalCredentials(deletedUserID: User.mock.id)

    #expect(deletedCount == 1)
    #expect(deletedLocalKeyIds.value == ["tdlk_deleted"])
    #expect(try setup.credentialStore.credential(id: "tdc_deleted") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func availabilityUsesStoredCredentialPolicy() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedPolicies = LockIsolated<[TrustedDevicePolicy]>([])
    let keyManager = MockTrustedDeviceKeyManager(
      isSupportedForPolicy: { policy in
        checkedPolicies.withValue { $0.append(policy) }
        return policy == .biometryOrDevicePasscode
      }
    )
    let localCredential = TrustedDeviceLocalCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      policy: .biometryOrDevicePasscode,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let setup = try makeTrustedDevicesWithLocalCredential(
      keyManager: keyManager,
      localCredential: localCredential
    )

    let availability = try await setup.trustedDevices.availability()

    #expect(availability.isAvailable)
    #expect(checkedPolicies.value == [.biometryOrDevicePasscode])
  }

  @Test
  func availabilityReturnsNoLocalCredentialWhenIdentifierHintDoesNotMatch() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeTrustedDevicesWithLocalCredential(localCredential: localCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      identifierHint: "sean@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.trustedDevices.availability(identifierHint: "sam@example.com")

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
  }

  @Test
  func signInUsesCreateChallengeAndAttemptsFirstFactor() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let capturedAttempt = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let signInService = MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockTrustedDeviceChallenge
      },
      attemptFirstFactor: { signInId, params in
        capturedAttempt.setValue((signInId, params))
        return .mockTrustedDeviceComplete
      }
    )
    let keyManager = MockTrustedDeviceKeyManager(sign: { clientData, localKeyId, localizedReason in
      #expect(clientData == trustedDeviceChallengeClientData)
      #expect(localKeyId == "tdlk_mock")
      #expect(localizedReason == "Sign in with Face ID.")
      return .init(clientData: clientData, signature: "sign_in_signature")
    })
    let setup = try makeTrustedDevicesWithLocalCredential(
      signInService: signInService,
      keyManager: keyManager
    )

    let signIn = try await setup.trustedDevices.signIn(reason: "Sign in with Face ID.")

    #expect(signIn == .mockTrustedDeviceComplete)
    #expect(capturedCreateParams.value?.strategy == .trustedDevice)
    #expect(capturedCreateParams.value?.trustedDeviceId == "tdc_123")
    #expect(capturedAttempt.value?.0 == "si_trusted_device")
    #expect(capturedAttempt.value?.1.strategy == .trustedDevice)
    #expect(capturedAttempt.value?.1.trustedDeviceId == "tdc_123")
    #expect(capturedAttempt.value?.1.clientData == trustedDeviceChallengeClientData)
    #expect(capturedAttempt.value?.1.signature == "sign_in_signature")
    #expect(capturedAttempt.value?.1.algorithm == .es256)
  }

  @Test
  func signInUsesNewestLocalCredentialWhenNoIdIsProvided() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeTrustedDevices(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockTrustedDeviceChallenge
      },
      attemptFirstFactor: { _, _ in .mockTrustedDeviceComplete }
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_old",
      localKeyId: "tdlk_old",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_new",
      localKeyId: "tdlk_new",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    _ = try await setup.trustedDevices.signIn()

    #expect(capturedCreateParams.value?.trustedDeviceId == "tdc_new")
  }

  @Test
  func signInUsesIdentifierHintToSelectMatchingLocalCredential() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeTrustedDevices(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockTrustedDeviceChallenge
      },
      attemptFirstFactor: { _, _ in .mockTrustedDeviceComplete }
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_sean",
      localKeyId: "tdlk_sean",
      identifierHint: "sean@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_sam",
      localKeyId: "tdlk_sam",
      identifierHint: "+15551234567",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    _ = try await setup.trustedDevices.signIn(identifierHint: "  SEAN@example.com  ")

    #expect(capturedCreateParams.value?.trustedDeviceId == "tdc_sean")
  }

  @Test
  func signInDeletesLocalCredentialWhenCreateReportsTrustedDeviceMissing() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let attemptWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in throw missingTrustedDeviceCredentialError() },
        attemptFirstFactor: { _, _ in
          attemptWasCalled.setValue(true)
          return .mockTrustedDeviceComplete
        }
      ),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.trustedDevices.signIn()
      Issue.record("Expected trusted-device sign-in to fail.")
    } catch let error as ClerkClientError {
      #expect(error.message == "This device is no longer trusted. Sign in another way to enroll it again.")
      #expect(attemptWasCalled.value == false)
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func signInDeletesLocalCredentialWhenAttemptReportsTrustedDeviceMissing() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in .mockTrustedDeviceChallenge },
        attemptFirstFactor: { _, _ in throw missingTrustedDeviceCredentialError() }
      ),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.trustedDevices.signIn()
      Issue.record("Expected trusted-device sign-in to fail.")
    } catch let error as ClerkClientError {
      #expect(error.message == "This device is no longer trusted. Sign in another way to enroll it again.")
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func signInKeepsLocalCredentialWhenCreateFailsForUnrelatedAPIError() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeTrustedDevicesWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in throw missingTrustedDeviceCredentialError(paramName: "identifier") }
      ),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.trustedDevices.signIn()
      Issue.record("Expected trusted-device sign-in to fail.")
    } catch let error as ClerkAPIError {
      #expect(error.code == "form_resource_not_found")
      #expect(deletedLocalKeyIds.value.isEmpty)
      #expect(try setup.credentialStore.credential(id: "tdc_123") == .mock)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func signInSkipsStaleNewerCredentialWhenSignedIn() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mock
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeTrustedDevices(
      trustedDeviceService: MockTrustedDeviceService(list: {
        [trustedDevice(id: "tdc_123", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      signInService: MockSignInService(
        create: { params in
          capturedCreateParams.setValue(params)
          return .mockTrustedDeviceChallenge
        },
        attemptFirstFactor: { _, _ in .mockTrustedDeviceComplete }
      ),
      keyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_123",
      localKeyId: "tdlk_old",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_new",
      localKeyId: "tdlk_new",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    _ = try await setup.trustedDevices.signIn()

    #expect(capturedCreateParams.value?.trustedDeviceId == "tdc_123")
    #expect(deletedLocalKeyIds.value == ["tdlk_new"])
    #expect(try setup.credentialStore.credential(id: "tdc_new") == nil)
  }

  @Test
  func signInRequiresCreateToReturnTrustedDeviceChallenge() async throws {
    Clerk.shared.environment = enabledTrustedDeviceEnvironment()
    Clerk.shared.client = .mockSignedOut
    let prepareWasCalled = LockIsolated(false)
    let signInService = MockSignInService(
      create: { _ in SignIn(id: "si_missing_challenge", status: .needsIdentifier) },
      prepareFirstFactor: { _, _ in
        prepareWasCalled.setValue(true)
        return .mockTrustedDeviceChallenge
      },
      attemptFirstFactor: { _, _ in .mockTrustedDeviceComplete }
    )
    let setup = try makeTrustedDevicesWithLocalCredential(signInService: signInService)

    do {
      _ = try await setup.trustedDevices.signIn(id: "tdc_123")
      Issue.record("Expected sign-in to fail when create does not return a trusted-device challenge.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Trusted-device sign-in did not return a challenge.")
      #expect(prepareWasCalled.value == false)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }
}

private let trustedDeviceChallengeClientData = "{\"challenge_id\":\"tdch_123\"}"
private let trustedDeviceChallenge = TrustedDeviceChallenge(
  challenge: "challenge",
  challengeId: "tdch_123",
  trustedDeviceId: "tdc_123",
  clientData: trustedDeviceChallengeClientData,
  expiresAt: Date(timeIntervalSince1970: 1_710_000_000),
  algorithm: .es256
)

private func enabledTrustedDeviceEnvironment() -> Clerk.Environment {
  var environment = Clerk.Environment.mock
  environment.authConfig.nativeSettings = .init(
    apiEnabled: true,
    trustedDeviceSignInEnabled: true
  )
  return environment
}

private func localCredential(
  id: String,
  localKeyId: String,
  userID: String = User.mock.id,
  appIdentifier: String = "com.clerk.example",
  identifierHint: String? = nil,
  createdAt: Date
) -> TrustedDeviceLocalCredential {
  TrustedDeviceLocalCredential(
    id: id,
    localKeyId: localKeyId,
    userID: userID,
    appIdentifier: appIdentifier,
    identifierHint: identifierHint,
    createdAt: createdAt,
    updatedAt: createdAt
  )
}

private func trustedDevice(
  id: String,
  createdAt: Date
) -> TrustedDevice {
  TrustedDevice(
    id: id,
    platform: .iOS,
    appIdentifier: "com.clerk.example",
    name: nil,
    algorithm: .es256,
    status: .active,
    createdAt: createdAt,
    updatedAt: createdAt
  )
}

private func missingTrustedDeviceCredentialError(
  paramName: String = "trusted_device_id"
) -> ClerkAPIError {
  ClerkAPIError(
    code: "form_resource_not_found",
    message: "is missing",
    longMessage: "The resource associated with the supplied trusted_device_id was not found.",
    meta: ["param_name": .string(paramName)],
    clerkTraceId: "trace_123"
  )
}

@MainActor
private func makeTrustedDevicesWithLocalCredential(
  trustedDeviceService: TrustedDeviceServiceProtocol = MockTrustedDeviceService(),
  signInService: SignInServiceProtocol = MockSignInService(),
  keyManager: MockTrustedDeviceKeyManager = MockTrustedDeviceKeyManager(),
  localCredential: TrustedDeviceLocalCredential = .mock
) throws -> (
  trustedDevices: TrustedDevices,
  credentialStore: TrustedDeviceLocalCredentialStore
) {
  let setup = makeTrustedDevices(
    trustedDeviceService: trustedDeviceService,
    signInService: signInService,
    keyManager: keyManager
  )
  try setup.credentialStore.save(localCredential)
  return setup
}

@MainActor
private func makeTrustedDevices(
  trustedDeviceService: TrustedDeviceServiceProtocol = MockTrustedDeviceService(),
  signInService: SignInServiceProtocol = MockSignInService(),
  keyManager: MockTrustedDeviceKeyManager = MockTrustedDeviceKeyManager()
) -> (
  trustedDevices: TrustedDevices,
  credentialStore: TrustedDeviceLocalCredentialStore
) {
  let credentialStore = TrustedDeviceLocalCredentialStore(keychain: InMemoryKeychain())
  let trustedDevices = TrustedDevices(
    trustedDeviceService: trustedDeviceService,
    signInService: signInService,
    keyManager: keyManager,
    credentialStore: credentialStore,
    appIdentifierProvider: { "com.clerk.example" }
  )
  return (trustedDevices, credentialStore)
}

extension SignIn {
  static var mockTrustedDeviceChallenge: SignIn {
    SignIn(
      id: "si_trusted_device",
      status: .needsIdentifier,
      firstFactorVerification: .init(
        status: .unverified,
        strategy: .trustedDevice,
        trustedDeviceChallenge: trustedDeviceChallenge
      )
    )
  }

  static var mockTrustedDeviceComplete: SignIn {
    SignIn(
      id: "si_trusted_device",
      status: .complete,
      createdSessionId: "sess_123"
    )
  }
}
