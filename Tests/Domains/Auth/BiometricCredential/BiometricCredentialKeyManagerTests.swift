@testable import ClerkKit
import CryptoTokenKit
import Foundation
#if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
import LocalAuthentication
#endif
import Security
import Testing

struct BiometricCredentialKeyManagerTests {
  @Test
  func localKeyDefaultsToBiometryCurrentSetPolicy() {
    let localKey = BiometricCredentialLocalKey(localKeyId: "tdlk_123", publicKeyJWK: "{}")

    #expect(localKey.policy == .biometryCurrentSet)
  }

  @Test
  func privateKeyAttributesUseSecureEnclaveAccessControl() throws {
    let accessControl = try BiometricCredentialKeyManager.makeAccessControl()

    let attributes = BiometricCredentialKeyManager.makePrivateKeyAttributes(
      localKeyId: "tdlk_123",
      accessControl: accessControl
    )

    #expect(attributes[kSecAttrKeyType as String] as? String == kSecAttrKeyTypeECSECPrimeRandom as String)
    #expect(attributes[kSecAttrKeySizeInBits as String] as? Int == 256)
    #expect(attributes[kSecAttrTokenID as String] as? String == kSecAttrTokenIDSecureEnclave as String)
    #if os(macOS)
    #expect(attributes[kSecUseDataProtectionKeychain as String] as? Bool == true)
    #else
    #expect(attributes[kSecUseDataProtectionKeychain as String] == nil)
    #endif

    let privateKeyAttributes = try #require(attributes[kSecPrivateKeyAttrs as String] as? [String: Any])
    #expect(privateKeyAttributes[kSecAttrIsPermanent as String] as? Bool == true)
    #expect(
      privateKeyAttributes[kSecAttrApplicationTag as String] as? Data ==
        Data("dev.clerk.trusted_device.tdlk_123".utf8)
    )
    #expect(privateKeyAttributes[kSecAttrAccessControl as String] != nil)
  }

  #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
  @Test
  func localAuthenticationPoliciesMatchBiometricCredentialPolicies() {
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicy(for: .biometryCurrentSet) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicy(for: .biometryAny) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicy(for: .biometryOrDevicePasscode) ==
        .deviceOwnerAuthentication
    )
  }

  @Test
  func localAuthenticationPoliciesForKeyCreationRequireBiometrics() {
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryCurrentSet) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryAny) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      BiometricCredentialKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryOrDevicePasscode) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
  }
  #endif

  @Test
  func privateKeyQueryUsesStableApplicationTag() {
    let query = BiometricCredentialKeyManager.privateKeyQuery(localKeyId: "tdlk_123")

    #expect(query[kSecClass as String] as? String == kSecClassKey as String)
    #expect(query[kSecAttrKeyClass as String] as? String == kSecAttrKeyClassPrivate as String)
    #expect(query[kSecAttrKeyType as String] as? String == kSecAttrKeyTypeECSECPrimeRandom as String)
    #expect(query[kSecAttrApplicationTag as String] as? Data == Data("dev.clerk.trusted_device.tdlk_123".utf8))
    #if os(macOS)
    #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
    #else
    #expect(query[kSecUseDataProtectionKeychain as String] == nil)
    #endif
  }

  @Test
  func publicKeyJWKRejectsInvalidRepresentation() throws {
    do {
      _ = try BiometricCredentialKeyManager.publicKeyJWK(fromX963Representation: Data(repeating: 0x01, count: 64))
      Issue.record("Expected invalid public key error.")
    } catch let error as BiometricCredentialKeyManagerError {
      #expect(error == .invalidPublicKey)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @MainActor
  @Test
  func failedPublicKeyExportDeletesCreatedKeyAndPreservesExportError() {
    enum Failure: Error, Equatable {
      case export
    }

    var deletedLocalKeyIds: [String] = []
    do {
      _ = try BiometricCredentialKeyManager.completeKeyCreation(
        localKeyId: "tdlk_created",
        policy: .biometryCurrentSet,
        exportPublicKeyJWK: {
          throw Failure.export
        },
        deleteKey: { localKeyId in
          deletedLocalKeyIds.append(localKeyId)
        }
      )
      Issue.record("Expected public-key export to fail.")
    } catch let error as Failure {
      #expect(error == .export)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }

    #expect(deletedLocalKeyIds == ["tdlk_created"])
  }

  @Test
  func base64URLEncodingOmitsPadding() {
    #expect(BiometricCredentialKeyManager.base64URLEncodedString(Data([0xFB, 0xFF, 0xEF])) == "-__v")
    #expect(!BiometricCredentialKeyManager.base64URLEncodedString(Data([0x01])).contains("="))
  }

  @Test
  func rawES256SignatureConvertsDEREncodedSignature() throws {
    let r = Data(repeating: 0x01, count: 32)
    let s = Data([0x00, 0x80]) + Data(repeating: 0x02, count: 31)
    let derSignature = Data([0x30, 0x45, 0x02, 0x20]) + r + Data([0x02, 0x21]) + s

    let rawSignature = try BiometricCredentialKeyManager.rawES256Signature(fromDEREncoded: derSignature)

    #expect(rawSignature == r + Data([0x80]) + Data(repeating: 0x02, count: 31))
  }

  @Test
  func rawES256SignaturePadsShortDERIntegers() throws {
    let derSignature = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])

    let rawSignature = try BiometricCredentialKeyManager.rawES256Signature(fromDEREncoded: derSignature)

    #expect(rawSignature == Data(repeating: 0x00, count: 31) + Data([0x01]) +
      Data(repeating: 0x00, count: 31) + Data([0x02]))
  }

  @Test
  func rawES256SignatureRejectsMalformedDER() throws {
    do {
      _ = try BiometricCredentialKeyManager.rawES256Signature(fromDEREncoded: Data([0x30, 0x03, 0x02, 0x01, 0x01]))
      Issue.record("Expected malformed DER signature error.")
    } catch let error as BiometricCredentialKeyManagerError {
      #expect(error == .signingFailed("Security returned an invalid ES256 signature."))
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func privateKeyLookupStatusMapsBiometricErrors() {
    #expect(
      BiometricCredentialKeyManager.privateKeyLookupError(for: errSecUserCanceled)
        as? BiometricCredentialKeyManagerError == .biometricAuthenticationCanceled
    )
    #expect(
      BiometricCredentialKeyManager.privateKeyLookupError(for: errSecAuthFailed)
        as? BiometricCredentialKeyManagerError == .biometricAuthenticationFailed
    )
    #expect(
      BiometricCredentialKeyManager.privateKeyLookupError(for: errSecInteractionNotAllowed)
        as? BiometricCredentialKeyManagerError == .biometricAuthenticationUnavailable
    )

    guard case let .unexpectedStatus(status)? = BiometricCredentialKeyManager.privateKeyLookupError(for: errSecNotAvailable)
      as? KeychainError
    else {
      Issue.record("Expected unknown keychain statuses to preserve their OSStatus.")
      return
    }

    #expect(status == errSecNotAvailable)
  }

  #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
  @Test(arguments: [LAError.Code.userCancel, .userFallback, .systemCancel, .appCancel])
  func signingErrorTreatsLocalAuthenticationCancellationAsCanceled(code: LAError.Code) {
    let error = NSError(
      domain: LAError.errorDomain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey: "Authentication canceled."]
    )

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .biometricAuthenticationCanceled)
  }

  @Test
  func signingErrorFindsCancellationInUnderlyingError() {
    let cancellation = NSError(domain: LAError.errorDomain, code: LAError.Code.systemCancel.rawValue)
    let error = NSError(
      domain: "com.clerk.tests.WrappingError",
      code: 1,
      userInfo: [NSUnderlyingErrorKey: cancellation]
    )

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .biometricAuthenticationCanceled)
  }

  @Test(arguments: [LAError.Code.authenticationFailed, .biometryLockout, .notInteractive])
  func signingErrorKeepsOtherLocalAuthenticationErrorsAsSigningFailures(code: LAError.Code) {
    let error = NSError(
      domain: LAError.errorDomain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey: "Biometry is locked out."]
    )

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .signingFailed("Biometry is locked out."))
  }
  #endif

  @Test
  func signingErrorTreatsSecurityUserCancelAsCanceled() {
    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecUserCanceled))

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .biometricAuthenticationCanceled)
  }

  @Test
  func signingErrorTreatsCryptoTokenKitUserCancelAsCanceled() {
    let error = NSError(domain: TKError.errorDomain, code: TKError.Code.canceledByUser.rawValue)

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .biometricAuthenticationCanceled)
  }

  @Test
  func signingErrorKeepsOtherCryptoTokenKitErrorsAsSigningFailures() {
    let error = NSError(
      domain: TKError.errorDomain,
      code: TKError.Code.authenticationNeeded.rawValue,
      userInfo: [NSLocalizedDescriptionKey: "Authentication is needed."]
    )

    #expect(BiometricCredentialKeyManager.signingError(from: error) == .signingFailed("Authentication is needed."))
  }

  @Test
  func signingErrorKeepsSecurityFailureMessage() {
    let error = NSError(
      domain: NSOSStatusErrorDomain,
      code: Int(errSecParam),
      userInfo: [NSLocalizedDescriptionKey: "One or more parameters passed to a function were not valid."]
    )

    #expect(
      BiometricCredentialKeyManager.signingError(from: error)
        == .signingFailed("One or more parameters passed to a function were not valid.")
    )
  }
}
