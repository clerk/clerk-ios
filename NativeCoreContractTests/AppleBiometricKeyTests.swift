@testable import ClerkKit
import Foundation
#if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
import LocalAuthentication
#endif
import Security
import Testing

struct AppleBiometricKeyTests {
  @Test
  func localKeyDefaultsToBiometryCurrentSetPolicy() {
    let localKey = AppleBiometricLocalKey(localKeyId: "tdlk_123", publicKeyJWK: "{}")

    #expect(localKey.policy == .biometryCurrentSet)
  }

  @Test
  func privateKeyAttributesUseSecureEnclaveAccessControl() throws {
    let accessControl = try AppleBiometricKeyManager.makeAccessControl()

    let attributes = AppleBiometricKeyManager.makePrivateKeyAttributes(
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

  @Test
  func accessControlFlagsMatchBiometricCredentialPolicies() {
    #expect(AppleBiometricKeyManager.accessControlFlags(for: .biometryCurrentSet) == [
      .privateKeyUsage,
      .biometryCurrentSet,
    ])
    #expect(AppleBiometricKeyManager.accessControlFlags(for: .biometryAny) == [
      .privateKeyUsage,
      .biometryAny,
    ])
    #expect(AppleBiometricKeyManager.accessControlFlags(for: .biometryOrDevicePasscode) == [
      .privateKeyUsage,
      .userPresence,
    ])
  }

  #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
  @Test
  func localAuthenticationPoliciesMatchBiometricCredentialPolicies() {
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicy(for: .biometryCurrentSet) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicy(for: .biometryAny) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicy(for: .biometryOrDevicePasscode) ==
        .deviceOwnerAuthentication
    )
  }

  @Test
  func localAuthenticationPoliciesForKeyCreationRequireBiometrics() {
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryCurrentSet) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryAny) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
    #expect(
      AppleBiometricKeyManager.localAuthenticationPolicyForKeyCreation(for: .biometryOrDevicePasscode) ==
        .deviceOwnerAuthenticationWithBiometrics
    )
  }
  #endif

  @Test
  func privateKeyQueryUsesStableApplicationTag() {
    let query = AppleBiometricKeyManager.privateKeyQuery(localKeyId: "tdlk_123")

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
  func publicKeyJWKEncodesP256X963Representation() throws {
    let x = Data(repeating: 0x01, count: 32)
    let y = Data(repeating: 0x02, count: 32)
    let representation = Data([0x04]) + x + y

    let jwk = try AppleBiometricKeyManager.publicKeyJWK(fromX963Representation: representation)
    let object = try #require(JSONSerialization.jsonObject(with: Data(jwk.utf8)) as? [String: String])

    #expect(object["kty"] == "EC")
    #expect(object["crv"] == "P-256")
    #expect(object["x"] == AppleBiometricKeyManager.base64URLEncodedString(x))
    #expect(object["y"] == AppleBiometricKeyManager.base64URLEncodedString(y))
    #expect(object["alg"] == "ES256")
  }

  @Test
  func publicKeyJWKRejectsInvalidRepresentation() throws {
    do {
      _ = try AppleBiometricKeyManager.publicKeyJWK(fromX963Representation: Data(repeating: 0x01, count: 64))
      Issue.record("Expected invalid public key error.")
    } catch let error as AppleBiometricKeyError {
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
      _ = try AppleBiometricKeyManager.completeKeyCreation(
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
    #expect(AppleBiometricKeyManager.base64URLEncodedString(Data([0xFB, 0xFF, 0xEF])) == "-__v")
    #expect(!AppleBiometricKeyManager.base64URLEncodedString(Data([0x01])).contains("="))
  }

  @Test
  func rawES256SignatureConvertsDEREncodedSignature() throws {
    let r = Data(repeating: 0x01, count: 32)
    let s = Data([0x00, 0x80]) + Data(repeating: 0x02, count: 31)
    let derSignature = Data([0x30, 0x45, 0x02, 0x20]) + r + Data([0x02, 0x21]) + s

    let rawSignature = try AppleBiometricKeyManager.rawES256Signature(fromDEREncoded: derSignature)

    #expect(rawSignature == r + Data([0x80]) + Data(repeating: 0x02, count: 31))
  }

  @Test
  func rawES256SignaturePadsShortDERIntegers() throws {
    let derSignature = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])

    let rawSignature = try AppleBiometricKeyManager.rawES256Signature(fromDEREncoded: derSignature)

    #expect(rawSignature == Data(repeating: 0x00, count: 31) + Data([0x01]) +
      Data(repeating: 0x00, count: 31) + Data([0x02]))
  }

  @Test
  func rawES256SignatureRejectsMalformedDER() throws {
    do {
      _ = try AppleBiometricKeyManager.rawES256Signature(fromDEREncoded: Data([0x30, 0x03, 0x02, 0x01, 0x01]))
      Issue.record("Expected malformed DER signature error.")
    } catch let error as AppleBiometricKeyError {
      #expect(error == .signingFailed("Security returned an invalid ES256 signature."))
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func privateKeyLookupStatusMapsBiometricErrors() {
    #expect(
      AppleBiometricKeyManager.privateKeyLookupError(for: errSecUserCanceled)
        as? AppleBiometricKeyError == .biometricAuthenticationCanceled
    )
    #expect(
      AppleBiometricKeyManager.privateKeyLookupError(for: errSecAuthFailed)
        as? AppleBiometricKeyError == .biometricAuthenticationFailed
    )
    #expect(
      AppleBiometricKeyManager.privateKeyLookupError(for: errSecInteractionNotAllowed)
        as? AppleBiometricKeyError == .biometricAuthenticationUnavailable
    )

    let error = AppleBiometricKeyManager.privateKeyLookupError(for: errSecNotAvailable) as? CoreError
    #expect(error?.code == "secure_storage_error_\(errSecNotAvailable)")
  }
}
