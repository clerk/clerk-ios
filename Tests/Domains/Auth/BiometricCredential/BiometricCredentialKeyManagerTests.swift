@testable import ClerkKit
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

  @Test
  func accessControlFlagsMatchBiometricCredentialPolicies() {
    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryCurrentSet) == [
      .privateKeyUsage,
      .biometryCurrentSet,
    ])
    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryAny) == [
      .privateKeyUsage,
      .biometryAny,
    ])
    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryOrDevicePasscode) == [
      .privateKeyUsage,
      .userPresence,
    ])
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
  func publicKeyJWKEncodesP256X963Representation() throws {
    let x = Data(repeating: 0x01, count: 32)
    let y = Data(repeating: 0x02, count: 32)
    let representation = Data([0x04]) + x + y

    let jwk = try BiometricCredentialKeyManager.publicKeyJWK(fromX963Representation: representation)
    let object = try #require(JSONSerialization.jsonObject(with: Data(jwk.utf8)) as? [String: String])

    #expect(object["kty"] == "EC")
    #expect(object["crv"] == "P-256")
    #expect(object["x"] == BiometricCredentialKeyManager.base64URLEncodedString(x))
    #expect(object["y"] == BiometricCredentialKeyManager.base64URLEncodedString(y))
    #expect(object["alg"] == "ES256")
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

  @MainActor
  @Test
  func mockKeyManagerSignsClientData() throws {
    let manager = MockBiometricCredentialKeyManager(sign: { clientData, localKeyId, localizedReason in
      #expect(clientData == "{\"challenge_id\":\"tdch_123\"}")
      #expect(localKeyId == "tdlk_123")
      #expect(localizedReason == "Use biometrics")
      return BiometricCredentialKeySignature(clientData: clientData, signature: "signature")
    })

    let signature = try manager.sign(
      clientData: "{\"challenge_id\":\"tdch_123\"}",
      localKeyId: "tdlk_123",
      localizedReason: "Use biometrics"
    )

    #expect(signature.clientData == "{\"challenge_id\":\"tdch_123\"}")
    #expect(signature.signature == "signature")
    #expect(signature.algorithm == .es256)
  }

  @MainActor
  @Test
  func mockKeyManagerSurfacesMissingKey() throws {
    let manager = MockBiometricCredentialKeyManager(sign: { _, _, _ in
      throw BiometricCredentialKeyManagerError.keyNotFound
    })

    do {
      _ = try manager.sign(clientData: "{}", localKeyId: "tdlk_missing")
      Issue.record("Expected missing key error.")
    } catch let error as BiometricCredentialKeyManagerError {
      #expect(error == .keyNotFound)
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }
}
