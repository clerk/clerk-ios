@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct BiometricCredentialsTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func listUsesBiometricCredentialService() async throws {
    let called = LockIsolated(false)
    let service = MockBiometricCredentialService(list: {
      called.setValue(true)
      return [.mock]
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      biometricCredentialService: service
    )

    let biometricCredentials = try await Clerk.shared.biometricCredentials.list()

    #expect(called.value == true)
    #expect(biometricCredentials == [.mock])
  }

  @Test
  func revokeUsesBiometricCredentialService() async throws {
    Clerk.shared.client = .mock
    let capturedBiometricCredentialId = LockIsolated<String?>(nil)
    let capturedSessionId = LockIsolated<String?>(nil)
    let service = MockBiometricCredentialService(revoke: { biometricCredentialId, sessionId in
      capturedBiometricCredentialId.setValue(biometricCredentialId)
      capturedSessionId.setValue(sessionId)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      biometricCredentialService: service
    )

    let biometricCredential = try await Clerk.shared.biometricCredentials.revoke(id: "tdc_123")

    #expect(capturedBiometricCredentialId.value == "tdc_123")
    #expect(capturedSessionId.value == Session.mock.id)
    #expect(biometricCredential == .mock)
  }

  @Test
  func availabilityReturnsAvailableLocalCredentialWithoutActiveSession() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential()

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
  }

  @Test
  func availabilityReturnsAvailableWithMultipleLocalCredentials() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = makeBiometricCredentials()
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

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func availabilityReconcilesServerCredentialWhenSessionIsActive() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(list: { [.mock] })
    )

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func localAvailabilityDoesNotReconcileServerCredentialWhenSessionIsActive() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(list: {
        Issue.record("Local availability should not fetch biometric credentials.")
        return []
      })
    )

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleReturnsValidForServerCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedBiometricCredentialId = LockIsolated<String?>(nil)
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(validateSignInCredential: { biometricCredentialId in
        capturedBiometricCredentialId.setValue(biometricCredentialId)
        return .init(valid: true)
      })
    )

    let result = await setup.biometricCredentials.validateLocalCredentialIfPossible()

    #expect(result == .valid)
    #expect(capturedBiometricCredentialId.value == "tdc_123")
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleDeletesMissingServerCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(validateSignInCredential: { _ in
        throw missingBiometricCredentialError()
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let result = await setup.biometricCredentials.validateLocalCredentialIfPossible()

    #expect(result == .invalid(.serverCredentialMissing))
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
  }

  @Test
  func validateLocalCredentialIfPossibleSkipsMissingNewestCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let validatedBiometricCredentialIds = LockIsolated<[String]>([])
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(validateSignInCredential: { biometricCredentialId in
        validatedBiometricCredentialIds.withValue { $0.append(biometricCredentialId) }
        if biometricCredentialId == "tdc_new" {
          throw missingBiometricCredentialError()
        }
        return .init(valid: true)
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    let result = await setup.biometricCredentials.validateLocalCredentialIfPossible()

    #expect(result == .valid)
    #expect(validatedBiometricCredentialIds.value == ["tdc_new", "tdc_old"])
    #expect(deletedLocalKeyIds.value == ["tdlk_new"])
    #expect(try setup.credentialStore.credential(id: "tdc_new") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_old") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleKeepsCredentialForTransientError() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(validateSignInCredential: { _ in
        throw URLError(.timedOut)
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let result = await setup.biometricCredentials.validateLocalCredentialIfPossible()

    #expect(result == .inconclusive)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func validateLocalCredentialIfPossibleIsInconclusiveWithoutCachedClient() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = nil
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(validateSignInCredential: { _ in
        Issue.record("Validation should not run without a cached client.")
        return .init(valid: true)
      })
    )

    let result = await setup.biometricCredentials.validateLocalCredentialIfPossible()

    #expect(result == .inconclusive)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func availabilitySkipsStaleNewerCredentialWhenSignedIn() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        [biometricCredential(id: "tdc_old", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == true)
    #expect(deletedLocalKeyIds.value == ["tdlk_new"])
    #expect(try setup.credentialStore.credential(id: "tdc_new") == nil)
  }

  @Test
  func availabilityDoesNotReconcileServerCredentialWhenSessionIsExpired() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = Client(
      id: "client_expired",
      sessions: [.mockExpired],
      lastActiveSessionId: Session.mockExpired.id,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(list: {
        Issue.record("Expired sessions should not trigger authenticated biometric-credential list.")
        return []
      })
    )

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func availabilityReturnsFeatureDisabledWhenNativeSettingIsOff() async throws {
    Clerk.shared.environment = .mock
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential()

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .nativeAPIDisabled)
  }

  @Test
  func availabilityDeletesMetadataWhenLocalKeyIsMissing() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: MockBiometricCredentialKeyManager(hasKey: { _ in false })
    )

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .localKeyMissing)
    #expect(try setup.credentialStore.all().isEmpty)
  }

  @Test
  func availabilityDeletesMetadataWhenServerCredentialIsMissing() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(list: { [] }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .serverCredentialMissing)
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.all().isEmpty)
  }

  @Test
  func availabilityIgnoresCredentialFromDifferentAppIdentifierBeforeCheckingKeys() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(keyManager: MockBiometricCredentialKeyManager(hasKey: { localKeyId in
      checkedLocalKeyIds.withValue { $0.append(localKeyId) }
      return false
    }))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
    #expect(checkedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func signInUsesCurrentAppCredentialWhenSharedKeychainContainsNewerCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeBiometricCredentials(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockBiometricCredentialChallenge
      },
      attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
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

    _ = try await setup.biometricCredentials.signIn()

    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_current_app")
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func availabilityIgnoresCredentialOwnedByDifferentUserWhenSignedIn() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let listWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        listWasCalled.setValue(true)
        return []
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    let availability = try await setup.biometricCredentials.availability(identifierHint: "sam@example.com")

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
    #expect(listWasCalled.value == false)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func availabilitySkipsNewestCredentialOwnedByDifferentUserWhenIdentifierHintIsNil() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let listWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        listWasCalled.setValue(true)
        return [biometricCredential(id: "tdc_active_user", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable)
    #expect(listWasCalled.value)
    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_active_user") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func availabilityUsesUserIDWhenIdentifierHintChanged() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        [biometricCredential(id: "tdc_current_user", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.biometricCredentials.currentUserAvailability()

    #expect(availability.isAvailable)
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") != nil)
  }

  @Test
  func localAvailabilityUsesUserIDWhenIdentifierHintChanged() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = makeBiometricCredentials()
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try setup.biometricCredentials.currentUserLocalAvailability()

    #expect(availability.isAvailable)
  }

  @Test
  func enrollCreatesKeyPreparesChallengeAttemptsAndPersistsMetadata() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let preparedParams = LockIsolated<BiometricCredential.PrepareEnrollmentParams?>(nil)
    let attemptedParams = LockIsolated<BiometricCredential.AttemptEnrollmentParams?>(nil)
    let biometricCredentialService = MockBiometricCredentialService(
      prepareEnrollment: { _, params in
        preparedParams.setValue(params)
        return .mock
      },
      attemptEnrollment: { _, params in
        attemptedParams.setValue(params)
        return .mock
      }
    )
    let keyManager = MockBiometricCredentialKeyManager(
      createKeyWithPolicy: { policy in
        #expect(policy == .biometryOrDevicePasscode)
        return .init(
          localKeyId: BiometricCredentialLocalKey.mock.localKeyId,
          publicKeyJWK: BiometricCredentialLocalKey.mock.publicKeyJWK,
          policy: policy
        )
      },
      sign: { clientData, localKeyId, localizedReason in
        #expect(clientData == BiometricCredentialChallenge.mock.clientData)
        #expect(localKeyId == BiometricCredentialLocalKey.mock.localKeyId)
        #expect(localizedReason == "Set up Face ID for future sign-ins.")
        return .init(clientData: clientData, signature: "enrollment_signature")
      }
    )
    let setup = makeBiometricCredentials(
      biometricCredentialService: biometricCredentialService,
      keyManager: keyManager
    )

    let biometricCredential = try await setup.biometricCredentials.enroll(
      name: "Sean's iPhone",
      identifierHint: "  Sean@Example.COM  ",
      reason: "Set up Face ID for future sign-ins.",
      policy: .biometryOrDevicePasscode
    )
    let localCredential = try #require(try setup.credentialStore.credential(id: "tdc_123"))

    #expect(biometricCredential == .mock)
    #expect(preparedParams.value?.appIdentifier == "com.clerk.example")
    #expect(preparedParams.value?.name == "Sean's iPhone")
    #expect(preparedParams.value?.publicKeyJWK == BiometricCredentialLocalKey.mock.publicKeyJWK)
    #expect(attemptedParams.value?.signature == "enrollment_signature")
    #expect(localCredential.localKeyId == BiometricCredentialLocalKey.mock.localKeyId)
    #expect(localCredential.userID == User.mock.id)
    #expect(localCredential.identifierHint == "sean@example.com")
    #expect(localCredential.policy == .biometryOrDevicePasscode)
  }

  @Test
  func enrollPinsInitiatingSessionAcrossCurrentSessionChange() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let requestedSessionIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(
        prepareEnrollment: { sessionId, _ in
          requestedSessionIds.withValue { $0.append(sessionId) }
          await MainActor.run {
            var client = Client.mock
            client.lastActiveSessionId = Session.mock2.id
            Clerk.shared.client = client
          }
          return .mock
        },
        attemptEnrollment: { sessionId, _ in
          requestedSessionIds.withValue { $0.append(sessionId) }
          return .mock
        }
      )
    )

    _ = try await setup.biometricCredentials.enroll()
    let localCredential = try #require(try setup.credentialStore.credential(id: BiometricCredential.mock.id))

    #expect(requestedSessionIds.value == [Session.mock.id, Session.mock.id])
    #expect(Clerk.shared.session?.id == Session.mock2.id)
    #expect(localCredential.userID == User.mock.id)
  }

  @Test
  func enrollUsesInitiatingSessionForRollbackAfterLocalSaveFailure() async {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let revokedBiometricCredentialIds = LockIsolated<[String]>([])
    let revokedSessionIds = LockIsolated<[String?]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(
        attemptEnrollment: { _, _ in
          await MainActor.run {
            var client = Client.mock
            client.lastActiveSessionId = Session.mock2.id
            Clerk.shared.client = client
          }
          return .mock
        },
        revoke: { biometricCredentialId, sessionId in
          revokedBiometricCredentialIds.withValue { $0.append(biometricCredentialId) }
          revokedSessionIds.withValue { $0.append(sessionId) }
          return .mock
        }
      ),
      credentialStoreKeychain: SetFailingKeychain()
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await setup.biometricCredentials.enroll()
    }

    #expect(revokedBiometricCredentialIds.value == [BiometricCredential.mock.id])
    #expect(revokedSessionIds.value == [Session.mock.id])
    #expect(Clerk.shared.session?.id == Session.mock2.id)
  }

  @Test
  func enrollReplacesOtherCurrentAppCredentialsAcrossUsersAfterSuccessfulEnrollment() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let revokedBiometricCredentialIds = LockIsolated<[String]>([])
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(revoke: { biometricCredentialId, _ in
        revokedBiometricCredentialIds.withValue { $0.append(biometricCredentialId) }
        return biometricCredential(id: biometricCredentialId, createdAt: Date(timeIntervalSinceReferenceDate: 10))
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    _ = try await setup.biometricCredentials.enroll()

    #expect(revokedBiometricCredentialIds.value.isEmpty)
    #expect(deletedLocalKeyIds.value == ["tdlk_current_user", "tdlk_other_user"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func enrollKeepsExistingCredentialsWhenEnrollmentFails() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(
        prepareEnrollment: { _, _ in .mock },
        attemptEnrollment: { _, _ in throw ClerkClientError(message: "Attempt failed") }
      ),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_existing",
      localKeyId: "tdlk_existing",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    do {
      _ = try await setup.biometricCredentials.enroll()
      Issue.record("Expected enrollment to fail.")
    } catch {
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.credential(id: "tdc_existing") != nil)
    }
  }

  @Test
  func enrollDoesNotCallBackendRevokeForReplacedLocalCredentials() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(revoke: { _, _ in
        throw ClerkClientError(message: "Revoke failed")
      }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )
    try setup.credentialStore.save(localCredential(
      id: "tdc_existing",
      localKeyId: "tdlk_existing",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    _ = try await setup.biometricCredentials.enroll()

    #expect(deletedLocalKeyIds.value == ["tdlk_existing"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
    #expect(try setup.credentialStore.credential(id: "tdc_existing") == nil)
  }

  @Test
  func enrollAllowsPendingSession() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
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
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(
        prepareEnrollment: { _, _ in
          prepareWasCalled.setValue(true)
          return .mock
        }
      )
    )

    _ = try await setup.biometricCredentials.enroll()

    #expect(prepareWasCalled.value)
  }

  @Test
  func enrollDefaultsToBiometryCurrentSetPolicy() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let createdKeyPolicies = LockIsolated<[BiometricCredentialPolicy]>([])
    let setup = makeBiometricCredentials(
      keyManager: MockBiometricCredentialKeyManager(
        createKeyWithPolicy: { policy in
          createdKeyPolicies.withValue { $0.append(policy) }
          return .init(
            localKeyId: BiometricCredentialLocalKey.mock.localKeyId,
            publicKeyJWK: BiometricCredentialLocalKey.mock.publicKeyJWK,
            policy: policy
          )
        }
      )
    )

    _ = try await setup.biometricCredentials.enroll()
    let localCredential = try #require(try setup.credentialStore.credential(id: BiometricCredential.mock.id))

    #expect(createdKeyPolicies.value == [.biometryCurrentSet])
    #expect(localCredential.policy == .biometryCurrentSet)
  }

  @Test
  func enrollDeletesGeneratedKeyWhenAttemptFails() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let biometricCredentialService = MockBiometricCredentialService(
      prepareEnrollment: { _, _ in .mock },
      attemptEnrollment: { _, _ in throw ClerkClientError(message: "Attempt failed") }
    )
    let keyManager = MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    })
    let setup = makeBiometricCredentials(
      biometricCredentialService: biometricCredentialService,
      keyManager: keyManager
    )

    do {
      _ = try await setup.biometricCredentials.enroll()
      Issue.record("Expected enrollment to fail.")
    } catch {
      #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
      #expect(try setup.credentialStore.all().isEmpty)
    }
  }

  @Test
  func enrollRequiresActiveOrPendingSession() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = makeBiometricCredentials()

    do {
      _ = try await setup.biometricCredentials.enroll()
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
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(revoke: { _, _ in .mock }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    let biometricCredential = try await setup.biometricCredentials.revoke(id: "tdc_123")

    #expect(biometricCredential == .mock)
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
  }

  @Test
  func revokeReturnsServerCredentialWhenLocalCleanupFails() async throws {
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(revoke: { _, _ in .mock }),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
        throw TestKeyDeletionError.failed
      })
    )

    let biometricCredential = try await setup.biometricCredentials.revoke(id: "tdc_123")

    #expect(biometricCredential == .mock)
    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func revokeCurrentDeviceCredentialUsesUserIDWhenIdentifierHintChanged() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let revokedBiometricCredentialIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(
        list: {
          [
            biometricCredential(id: "tdc_current_user", createdAt: Date(timeIntervalSinceReferenceDate: 10)),
            biometricCredential(id: "tdc_other_user", createdAt: Date(timeIntervalSinceReferenceDate: 20)),
          ]
        },
        revoke: { biometricCredentialId, _ in
          revokedBiometricCredentialIds.withValue { $0.append(biometricCredentialId) }
          return biometricCredential(id: biometricCredentialId, createdAt: Date(timeIntervalSinceReferenceDate: 10))
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

    let revokedBiometricCredential = try await setup.biometricCredentials.revokeCurrentDeviceCredential()

    #expect(revokedBiometricCredential?.id == "tdc_current_user")
    #expect(revokedBiometricCredentialIds.value == ["tdc_current_user"])
    #expect(try setup.credentialStore.credential(id: "tdc_current_user") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_user") != nil)
  }

  @Test
  func revokeCurrentDeviceCredentialReturnsNilWhenNoLocalCredentialIsAvailable() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let revokeWasCalled = LockIsolated(false)
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(revoke: { _, _ in
        revokeWasCalled.setValue(true)
        return .mock
      })
    )

    let biometricCredential = try await setup.biometricCredentials.revokeCurrentDeviceCredential()

    #expect(biometricCredential == nil)
    #expect(revokeWasCalled.value == false)
  }

  @Test
  func revokeCurrentDeviceCredentialAllowsPendingSession() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
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
    let revokedBiometricCredentialIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      biometricCredentialService: MockBiometricCredentialService(revoke: { biometricCredentialId, _ in
        revokedBiometricCredentialIds.withValue { $0.append(biometricCredentialId) }
        return .mock
      })
    )

    _ = try await setup.biometricCredentials.revokeCurrentDeviceCredential()

    #expect(revokedBiometricCredentialIds.value == ["tdc_123"])
  }

  @Test
  func revokeCurrentDeviceCredentialRequiresActiveOrPendingSession() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential()

    do {
      _ = try await setup.biometricCredentials.revokeCurrentDeviceCredential()
      Issue.record("Expected revoking a current-device credential to require an active or pending session.")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("active or pending Clerk session") == true)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func forgetLocalCredentialsDeletesDeletedUserIDAfterCurrentUserIsCleared() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    let deletedCount = try setup.biometricCredentials.forgetLocalCredentials(deletedUserID: User.mock.id)

    #expect(deletedCount == 1)
    #expect(deletedLocalKeyIds.value == ["tdlk_deleted"])
    #expect(try setup.credentialStore.credential(id: "tdc_deleted") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func availabilityUsesStoredCredentialPolicy() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedPolicies = LockIsolated<[BiometricCredentialPolicy]>([])
    let keyManager = MockBiometricCredentialKeyManager(
      isSupportedForPolicy: { policy in
        checkedPolicies.withValue { $0.append(policy) }
        return policy == .biometryOrDevicePasscode
      }
    )
    let localCredential = BiometricCredentialLocalRecord(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      policy: .biometryOrDevicePasscode,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: keyManager,
      localCredential: localCredential
    )

    let availability = try await setup.biometricCredentials.availability()

    #expect(availability.isAvailable)
    #expect(checkedPolicies.value == [.biometryOrDevicePasscode])
  }

  @Test
  func availabilityReturnsNoLocalCredentialWhenIdentifierHintDoesNotMatch() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential(localCredential: localCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      identifierHint: "sean@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try await setup.biometricCredentials.availability(identifierHint: "sam@example.com")

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
  }

  @Test
  func signInUsesCreateChallengeAndAttemptsFirstFactor() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let capturedAttempt = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let signInService = MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockBiometricCredentialChallenge
      },
      attemptFirstFactor: { signInId, params in
        capturedAttempt.setValue((signInId, params))
        return .mockBiometricCredentialComplete
      }
    )
    let keyManager = MockBiometricCredentialKeyManager(sign: { clientData, localKeyId, localizedReason in
      #expect(clientData == biometricCredentialChallengeClientData)
      #expect(localKeyId == "tdlk_mock")
      #expect(localizedReason == "Sign in with Face ID.")
      return .init(clientData: clientData, signature: "sign_in_signature")
    })
    let setup = try makeBiometricCredentialsWithLocalCredential(
      signInService: signInService,
      keyManager: keyManager
    )

    let signIn = try await setup.biometricCredentials.signIn(reason: "Sign in with Face ID.")

    #expect(signIn == .mockBiometricCredentialComplete)
    #expect(capturedCreateParams.value?.strategy == .biometricCredential)
    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_123")
    #expect(capturedAttempt.value?.0 == "si_trusted_device")
    #expect(capturedAttempt.value?.1.strategy == .biometricCredential)
    #expect(capturedAttempt.value?.1.biometricCredentialId == "tdc_123")
    #expect(capturedAttempt.value?.1.clientData == biometricCredentialChallengeClientData)
    #expect(capturedAttempt.value?.1.signature == "sign_in_signature")
    #expect(capturedAttempt.value?.1.algorithm == .es256)
  }

  @Test
  func signInUsesNewestLocalCredentialWhenNoIdIsProvided() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeBiometricCredentials(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockBiometricCredentialChallenge
      },
      attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
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

    _ = try await setup.biometricCredentials.signIn()

    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_new")
  }

  @Test
  func signInSkipsCredentialOwnedByDifferentUserWhenSessionIsActive() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let listWasCalled = LockIsolated(false)
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        listWasCalled.setValue(true)
        return [biometricCredential(id: "tdc_active_user", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      signInService: MockSignInService(
        create: { params in
          capturedCreateParams.setValue(params)
          return .mockBiometricCredentialChallenge
        },
        attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
      )
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

    _ = try await setup.biometricCredentials.signIn()

    #expect(listWasCalled.value)
    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_active_user")
  }

  @Test
  func signInUsesIdentifierHintToSelectMatchingLocalCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let setup = makeBiometricCredentials(signInService: MockSignInService(
      create: { params in
        capturedCreateParams.setValue(params)
        return .mockBiometricCredentialChallenge
      },
      attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
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

    _ = try await setup.biometricCredentials.signIn(identifierHint: "  SEAN@example.com  ")

    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_sean")
  }

  @Test
  func signInDeletesLocalCredentialWhenCreateReportsBiometricCredentialMissing() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let attemptWasCalled = LockIsolated(false)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in throw missingBiometricCredentialError(code: "trusted_device_not_registered") },
        attemptFirstFactor: { _, _ in
          attemptWasCalled.setValue(true)
          return .mockBiometricCredentialComplete
        }
      ),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.biometricCredentials.signIn()
      Issue.record("Expected biometric sign-in to fail.")
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
  func signInDeletesLocalCredentialWhenAttemptReportsBiometricCredentialMissing() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in .mockBiometricCredentialChallenge },
        attemptFirstFactor: { _, _ in throw missingBiometricCredentialError() }
      ),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.biometricCredentials.signIn()
      Issue.record("Expected biometric sign-in to fail.")
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
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = try makeBiometricCredentialsWithLocalCredential(
      signInService: MockSignInService(
        create: { _ in throw missingBiometricCredentialError(paramName: "identifier") }
      ),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      })
    )

    do {
      _ = try await setup.biometricCredentials.signIn()
      Issue.record("Expected biometric sign-in to fail.")
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
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let capturedCreateParams = LockIsolated<SignIn.CreateParams?>(nil)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(
      biometricCredentialService: MockBiometricCredentialService(list: {
        [biometricCredential(id: "tdc_123", createdAt: Date(timeIntervalSinceReferenceDate: 10))]
      }),
      signInService: MockSignInService(
        create: { params in
          capturedCreateParams.setValue(params)
          return .mockBiometricCredentialChallenge
        },
        attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
      ),
      keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
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

    _ = try await setup.biometricCredentials.signIn()

    #expect(capturedCreateParams.value?.biometricCredentialId == "tdc_123")
    #expect(deletedLocalKeyIds.value == ["tdlk_new"])
    #expect(try setup.credentialStore.credential(id: "tdc_new") == nil)
  }

  @Test
  func signInRequiresCreateToReturnBiometricCredentialChallenge() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let prepareWasCalled = LockIsolated(false)
    let signInService = MockSignInService(
      create: { _ in SignIn(id: "si_missing_challenge", status: .needsIdentifier) },
      prepareFirstFactor: { _, _ in
        prepareWasCalled.setValue(true)
        return .mockBiometricCredentialChallenge
      },
      attemptFirstFactor: { _, _ in .mockBiometricCredentialComplete }
    )
    let setup = try makeBiometricCredentialsWithLocalCredential(signInService: signInService)

    do {
      _ = try await setup.biometricCredentials.signIn(id: "tdc_123")
      Issue.record("Expected sign-in to fail when create does not return a biometric-credential challenge.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Biometric sign-in did not return a challenge.")
      #expect(prepareWasCalled.value == false)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }
}

private let biometricCredentialChallengeClientData = "{\"challenge_id\":\"tdch_123\"}"
private var biometricCredentialChallenge: BiometricCredentialChallenge {
  BiometricCredentialChallenge(
    challenge: "challenge",
    challengeId: "tdch_123",
    biometricCredentialId: "tdc_123",
    clientData: biometricCredentialChallengeClientData,
    expiresAt: Date(timeIntervalSinceNow: 300),
    algorithm: .es256
  )
}

private func enabledBiometricCredentialEnvironment() -> Clerk.Environment {
  var environment = Clerk.Environment.mock
  environment.authConfig.nativeSettings = .init(
    apiEnabled: true,
    biometricSignInEnabled: true
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
) -> BiometricCredentialLocalRecord {
  BiometricCredentialLocalRecord(
    id: id,
    localKeyId: localKeyId,
    userID: userID,
    appIdentifier: appIdentifier,
    identifierHint: identifierHint,
    createdAt: createdAt,
    updatedAt: createdAt
  )
}

private func biometricCredential(
  id: String,
  createdAt: Date
) -> BiometricCredential {
  BiometricCredential(
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

private func missingBiometricCredentialError(
  code: String = "form_resource_not_found",
  paramName: String = "trusted_device_id"
) -> ClerkAPIError {
  ClerkAPIError(
    code: code,
    message: "is missing",
    longMessage: "The resource associated with the supplied trusted_device_id was not found.",
    meta: ["param_name": .string(paramName)],
    clerkTraceId: "trace_123"
  )
}

private enum TestKeyDeletionError: Error {
  case failed
}

@MainActor
private func makeBiometricCredentialsWithLocalCredential(
  biometricCredentialService: BiometricCredentialServiceProtocol = MockBiometricCredentialService(),
  signInService: SignInServiceProtocol = MockSignInService(),
  keyManager: MockBiometricCredentialKeyManager = MockBiometricCredentialKeyManager(),
  localCredential: BiometricCredentialLocalRecord = .mock
) throws -> (
  biometricCredentials: BiometricCredentials,
  credentialStore: BiometricCredentialLocalStore
) {
  let setup = makeBiometricCredentials(
    biometricCredentialService: biometricCredentialService,
    signInService: signInService,
    keyManager: keyManager
  )
  try setup.credentialStore.save(localCredential)
  return setup
}

@MainActor
private func makeBiometricCredentials(
  biometricCredentialService: BiometricCredentialServiceProtocol = MockBiometricCredentialService(),
  signInService: SignInServiceProtocol = MockSignInService(),
  keyManager: MockBiometricCredentialKeyManager = MockBiometricCredentialKeyManager(),
  credentialStoreKeychain: any KeychainStorage = InMemoryKeychain()
) -> (
  biometricCredentials: BiometricCredentials,
  credentialStore: BiometricCredentialLocalStore
) {
  let credentialStore = BiometricCredentialLocalStore(keychain: credentialStoreKeychain)
  let biometricCredentials = BiometricCredentials(
    biometricCredentialService: biometricCredentialService,
    signInService: signInService,
    keyManager: keyManager,
    credentialStore: credentialStore,
    appIdentifierProvider: { "com.clerk.example" }
  )
  return (biometricCredentials, credentialStore)
}

extension SignIn {
  static var mockBiometricCredentialChallenge: SignIn {
    SignIn(
      id: "si_trusted_device",
      status: .needsIdentifier,
      firstFactorVerification: .init(
        status: .unverified,
        strategy: .biometricCredential,
        biometricCredentialChallenge: biometricCredentialChallenge
      )
    )
  }

  static var mockBiometricCredentialComplete: SignIn {
    SignIn(
      id: "si_trusted_device",
      status: .complete,
      createdSessionId: "sess_123"
    )
  }
}

extension BiometricCredentialsTests {
  @Test(arguments: [Session.BiometricVerificationLevel.firstFactor, .secondFactor])
  func reverifyResolvesUserForSessionReturnedByBackend(level: Session.BiometricVerificationLevel) async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    // The session being reverified belongs to a different user than the active session.
    var client = Client.mock
    client.sessions = [.mock2, .mock]
    client.lastActiveSessionId = Session.mock2.id
    Clerk.shared.client = client
    let calls = LockIsolated<[String]>([])
    let factor = Verification(strategy: .biometricCredential, biometricCredentialChallenge: biometricCredentialChallenge)
    let service = MockSessionService(
      startVerification: { id, _ in
        #expect(id == Session.mock.id)
        calls.withValue { $0.append("start") }
        return try decodedBiometricReverification(status: .needsFirstFactor)
      },
      prepareFirstFactorVerification: { id, params in
        #expect(level == .firstFactor)
        #expect(id == Session.mock.id)
        #expect(params.biometricCredentialId == "tdc_123")
        calls.withValue { $0.append("prepare") }
        var prepared = try decodedBiometricReverification(status: .needsFirstFactor)
        prepared.firstFactorVerification = factor
        return prepared
      },
      attemptFirstFactorVerification: { id, params in
        #expect(id == Session.mock.id)
        if level == .secondFactor {
          #expect(params.strategy == .password)
          #expect(params.password == "test-password")
          calls.withValue { $0.append("password") }
          return try decodedBiometricReverification(status: .needsSecondFactor)
        }
        #expect(params.strategy == .biometricCredential)
        #expect(params.biometricCredentialId == "tdc_123")
        calls.withValue { $0.append("attempt") }
        return try decodedBiometricReverification(status: .complete)
      },
      prepareSecondFactorVerification: { id, params in
        #expect(level == .secondFactor)
        #expect(id == Session.mock.id)
        #expect(params.biometricCredentialId == "tdc_123")
        calls.withValue { $0.append("prepare") }
        var prepared = try decodedBiometricReverification(status: .needsSecondFactor)
        prepared.secondFactorVerification = factor
        return prepared
      },
      attemptSecondFactorVerification: { id, params in
        #expect(level == .secondFactor)
        #expect(id == Session.mock.id)
        #expect(params.strategy == .biometricCredential)
        #expect(params.biometricCredentialId == "tdc_123")
        calls.withValue { $0.append("attempt") }
        return try decodedBiometricReverification(status: .complete)
      }
    )
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential(keyManager: MockBiometricCredentialKeyManager(sign: { data, key, _ in
      #expect(key == BiometricCredentialLocalRecord.mock.localKeyId)
      calls.withValue { $0.append("sign") }
      return .init(clientData: data, signature: "signed-challenge")
    }))

    var verification = try await Session.mock.startVerification(level: .multiFactor)
    if level == .secondFactor {
      let session = try #require(verification.session)
      #expect(session.user == nil)
      verification = try await session.verifyWithPassword("test-password")
      #expect(verification.status == .needsSecondFactor)
    }
    let session = try #require(verification.session)
    #expect(session.user == nil)
    let result = try await session.verifyWithBiometrics(level: level, biometricCredentials: setup.biometricCredentials)

    #expect(result.status == .complete)
    #expect(result.session?.id == Session.mock.id)
    #expect(Clerk.shared.session?.id == Session.mock2.id)
    #expect(calls.value == (level == .firstFactor
        ? ["start", "prepare", "sign", "attempt"]
        : ["start", "password", "prepare", "sign", "attempt"]))
  }

  @Test(arguments: [Session.BiometricVerificationLevel.firstFactor, .secondFactor], [false, true])
  func reverifyRejectsMissingUserInMatchingClientSession(
    level: Session.BiometricVerificationLevel,
    includesMatchingSession: Bool
  ) async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    var client = Client.mock
    client.sessions = [.mock2]
    client.lastActiveSessionId = Session.mock2.id
    let verification = try decodedBiometricReverification(status: level == .firstFactor ? .needsFirstFactor : .needsSecondFactor)
    let session = try #require(verification.session)
    if includesMatchingSession {
      client.sessions.append(session)
    }
    Clerk.shared.client = client
    let service = MockSessionService(
      prepareFirstFactorVerification: { _, _ in
        Issue.record("Must resolve the session's user before preparing a challenge.")
        return .mockNeedsFirstFactor
      },
      prepareSecondFactorVerification: { _, _ in
        Issue.record("Must resolve the session's user before preparing a challenge.")
        return .mockNeedsSecondFactor
      }
    )
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    // A usable credential for the active user must not substitute for the missing owner.
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: MockBiometricCredentialKeyManager(sign: { _, _, _ in
        Issue.record("Must not prompt without resolving the session's user.")
        throw CancellationError()
      }),
      localCredential: localCredential(id: "tdc_other", localKeyId: "other-key", userID: User.mock2.id, createdAt: .now)
    )

    await #expect(throws: ClerkClientError.self) {
      try await session.verifyWithBiometrics(level: level, biometricCredentials: setup.biometricCredentials)
    }
  }

  @Test(arguments: [Session.BiometricVerificationLevel.firstFactor, .secondFactor])
  func reverifySignsSessionChallengeAndClearsCachedTokens(level: Session.BiometricVerificationLevel) async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    let session = Session.mock
    let calls = LockIsolated<[String]>([])
    let factor = Verification(strategy: .biometricCredential, biometricCredentialChallenge: biometricCredentialChallenge)
    let prepared = SessionVerification(
      status: level == .firstFactor ? .needsFirstFactor : .needsSecondFactor,
      level: .multiFactor,
      firstFactorVerification: level == .firstFactor ? factor : nil,
      secondFactorVerification: level == .secondFactor ? factor : nil
    )
    let service = MockSessionService(
      prepareFirstFactorVerification: { id, params in
        #expect(level == .firstFactor)
        #expect(id == session.id)
        #expect(params.biometricCredentialId == "tdc_123")
        #expect(params.strategy == .biometricCredential)
        calls.withValue { $0.append("prepare") }
        return prepared
      },
      attemptFirstFactorVerification: { id, params in
        #expect(level == .firstFactor)
        #expect(id == session.id)
        #expect(params.strategy == .biometricCredential)
        #expect(params.biometricCredentialId == "tdc_123")
        #expect(params.clientData == biometricCredentialChallengeClientData)
        #expect(params.signature == "signed-challenge")
        #expect(params.algorithm == .es256)
        calls.withValue { $0.append("attempt") }
        return SessionVerification(status: .complete, level: .multiFactor)
      },
      prepareSecondFactorVerification: { id, params in
        #expect(level == .secondFactor)
        #expect(id == session.id)
        #expect(params.biometricCredentialId == "tdc_123")
        #expect(params.strategy == .biometricCredential)
        calls.withValue { $0.append("prepare") }
        return prepared
      },
      attemptSecondFactorVerification: { id, params in
        #expect(level == .secondFactor)
        #expect(id == session.id)
        #expect(params.strategy == .biometricCredential)
        #expect(params.biometricCredentialId == "tdc_123")
        #expect(params.clientData == biometricCredentialChallengeClientData)
        #expect(params.signature == "signed-challenge")
        #expect(params.algorithm == .es256)
        calls.withValue { $0.append("attempt") }
        return SessionVerification(status: .complete, level: .multiFactor)
      }
    )
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential(
      signInService: MockSignInService(create: { _ in
        Issue.record("Reverification must not create a sign-in.")
        return .mock
      }),
      keyManager: MockBiometricCredentialKeyManager(sign: { data, key, reason in
        #expect(data == biometricCredentialChallengeClientData)
        #expect(key == BiometricCredentialLocalRecord.mock.localKeyId)
        #expect(reason == "Confirm payment")
        calls.withValue { $0.append("sign") }
        return .init(clientData: data, signature: "signed-challenge")
      })
    )
    await SessionTokensCache.shared.insertToken(.init(jwt: "stale.jwt"), cacheKey: session.tokenCacheKey(template: nil))
    let result = try await session.verifyWithBiometrics(reason: "Confirm payment", level: level, biometricCredentials: setup.biometricCredentials)
    #expect(result.status == .complete)
    #expect(calls.value == ["prepare", "sign", "attempt"])
    #expect(await SessionTokensCache.shared.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
  }

  @Test
  func reverifyRejectsAnotherUsersCredentialBeforeNetworkOrBiometricPrompt() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: MockBiometricCredentialKeyManager(sign: { _, _, _ in
        Issue.record("Must not prompt for another user's credential.")
        throw CancellationError()
      }),
      localCredential: localCredential(id: "tdc_other", localKeyId: "other-key", userID: "other-user", createdAt: .now)
    )
    let service = MockSessionService(prepareFirstFactorVerification: { _, _ in
      Issue.record("Must not prepare another user's credential.")
      return .mockNeedsFirstFactor
    })
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    await #expect(throws: ClerkClientError.self) {
      try await Session.mock.verifyWithBiometrics(biometricCredentials: setup.biometricCredentials)
    }
  }

  @Test(arguments: [false, true])
  func reverifyRejectsMissingOrMismatchedChallengeBeforePrompt(mismatched: Bool) async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    var challenge = biometricCredentialChallenge
    challenge.biometricCredentialId = "tdc_other"
    let prepared = SessionVerification(status: .needsFirstFactor, level: .firstFactor,
                                       firstFactorVerification: mismatched ? Verification(strategy: .biometricCredential, biometricCredentialChallenge: challenge) : nil)
    let service = MockSessionService(prepareFirstFactorVerification: { _, _ in prepared })
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential(keyManager: MockBiometricCredentialKeyManager(sign: { _, _, _ in
      Issue.record("Must not sign an invalid challenge.")
      throw CancellationError()
    }))
    await #expect(throws: ClerkClientError.self) {
      try await Session.mock.verifyWithBiometrics(biometricCredentials: setup.biometricCredentials)
    }
  }

  @Test
  func reverifyCancellationDoesNotSubmitOrDeleteCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    let service = MockSessionService(
      prepareFirstFactorVerification: { _, _ in
        SessionVerification(status: .needsFirstFactor, level: .firstFactor,
                            firstFactorVerification: Verification(strategy: .biometricCredential, biometricCredentialChallenge: biometricCredentialChallenge))
      },
      attemptFirstFactorVerification: { _, _ in
        Issue.record("Cancelled biometrics must not submit a verification.")
        return .mockComplete
      }
    )
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential(keyManager: MockBiometricCredentialKeyManager(sign: { _, _, _ in
      throw BiometricCredentialKeyManagerError.biometricAuthenticationCanceled
    }))
    await #expect(throws: BiometricCredentialKeyManagerError.self) {
      try await Session.mock.verifyWithBiometrics(biometricCredentials: setup.biometricCredentials)
    }
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test(arguments: [Session.BiometricVerificationLevel.firstFactor, .secondFactor])
  func reverifyExpiredChallengeDoesNotPromptSubmitOrDeleteCredential(level: Session.BiometricVerificationLevel) async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    var challenge = biometricCredentialChallenge
    challenge.expiresAt = .distantPast
    let factor = Verification(strategy: .biometricCredential, biometricCredentialChallenge: challenge)
    let prepared = SessionVerification(
      status: level == .firstFactor ? .needsFirstFactor : .needsSecondFactor,
      level: .multiFactor,
      firstFactorVerification: level == .firstFactor ? factor : nil,
      secondFactorVerification: level == .secondFactor ? factor : nil
    )
    let service = MockSessionService(
      prepareFirstFactorVerification: { _, _ in
        #expect(level == .firstFactor)
        return prepared
      },
      attemptFirstFactorVerification: { _, _ in
        Issue.record("Expired challenges must not submit a first-factor verification.")
        return .mockComplete
      },
      prepareSecondFactorVerification: { _, _ in
        #expect(level == .secondFactor)
        return prepared
      },
      attemptSecondFactorVerification: { _, _ in
        Issue.record("Expired challenges must not submit a second-factor verification.")
        return .mockComplete
      }
    )
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential(keyManager: MockBiometricCredentialKeyManager(
      sign: { _, _, _ in
        Issue.record("Expired challenges must not show the biometric prompt.")
        throw CancellationError()
      },
      deleteKey: { _ in
        Issue.record("An expired challenge must not delete the enrolled key.")
      }
    ))

    do {
      _ = try await Session.mock.verifyWithBiometrics(level: level, biometricCredentials: setup.biometricCredentials)
      Issue.record("Expected an expired challenge to fail before signing.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Biometric reverification challenge has expired.")
    }
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func reverifyRemovesRevokedCredential() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    let service = MockSessionService(prepareFirstFactorVerification: { _, _ in
      throw missingBiometricCredentialError(code: "trusted_device_not_registered")
    })
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), sessionService: service)
    let setup = try makeBiometricCredentialsWithLocalCredential()
    await #expect(throws: ClerkClientError.self) {
      try await Session.mock.verifyWithBiometrics(biometricCredentials: setup.biometricCredentials)
    }
    #expect(try setup.credentialStore.credential(id: "tdc_123") == nil)
  }

  @Test
  func biometricReverificationParamsMatchBackendWireNames() throws {
    func json(_ value: some Encodable) throws -> [String: Any] {
      try #require(JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(value)) as? [String: Any])
    }
    let prepareFirst = try json(Session.PrepareFirstFactorVerificationParams(strategy: .biometricCredential, biometricCredentialId: "tdc_123"))
    let prepareSecond = try json(Session.PrepareSecondFactorVerificationParams(strategy: .biometricCredential, biometricCredentialId: "tdc_123"))
    let attemptFirst = try json(Session.AttemptFirstFactorVerificationParams(strategy: .biometricCredential,
                                                                             biometricCredentialId: "tdc_123", clientData: "exact-data", signature: "signature", algorithm: .es256))
    let attemptSecond = try json(Session.AttemptSecondFactorVerificationParams(strategy: .biometricCredential,
                                                                               biometricCredentialId: "tdc_123", clientData: "exact-data", signature: "signature", algorithm: .es256))
    for params in [prepareFirst, prepareSecond, attemptFirst, attemptSecond] {
      #expect(params["strategy"] as? String == "trusted_device")
      #expect(params["trusted_device_id"] as? String == "tdc_123")
      #expect(params["biometric_credential_id"] == nil)
    }
    for params in [attemptFirst, attemptSecond] {
      #expect(params["client_data"] as? String == "exact-data")
      #expect(params["signature"] as? String == "signature")
      #expect(params["algorithm"] as? String == "ES256")
    }
  }
}

/// Reverification embeds a lightweight session, unlike the hydrated sessions in the client.
private func decodedBiometricReverification(status: SessionVerification.Status) throws -> SessionVerification {
  let json = """
  {
    "object": "session_reverification",
    "status": "\(status.rawValue)",
    "level": "multi_factor",
    "session": {
      "object": "session",
      "id": "\(Session.mock.id)",
      "status": "active",
      "user": null,
      "last_active_at": 1710000000000,
      "expire_at": 1710600000000,
      "abandon_at": 1712600000000,
      "created_at": 1710000000000,
      "updated_at": 1710000000000
    }
  }
  """
  return try JSONDecoder.clerkDecoder.decode(SessionVerification.self, from: Data(json.utf8))
}
