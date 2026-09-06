#if !os(watchOS)
import AuthenticationServices
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ClerkJSPasskeyAction: String {
  case create
  case get
}

struct ClerkJSPasskeyError: Error, Equatable {
  var code: String
  var message: String

  var json: String {
    let payload = ["code": code, "message": message]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8)
    else {
      return "{\"code\":\"passkey_registration_failed\",\"message\":\"Passkey failed\"}"
    }
    return text
  }

  static func from(_ error: Error, action: ClerkJSPasskeyAction) -> ClerkJSPasskeyError {
    if error is CancellationError {
      return ClerkJSPasskeyError(code: "passkey_operation_aborted", message: error.localizedDescription)
    }
    let failed: String
    let cancelled: String
    switch action {
    case .create:
      failed = "passkey_registration_failed"
      cancelled = "passkey_registration_cancelled"
    case .get:
      failed = "passkey_retrieval_failed"
      cancelled = "passkey_retrieval_cancelled"
    }
    let nsError = error as NSError
    guard nsError.domain == ASAuthorizationError.errorDomain,
          let code = ASAuthorizationError.Code(rawValue: nsError.code)
    else {
      return ClerkJSPasskeyError(code: failed, message: error.localizedDescription)
    }
    switch code {
    case .canceled:
      return ClerkJSPasskeyError(code: cancelled, message: error.localizedDescription)
    case .invalidResponse:
      return ClerkJSPasskeyError(code: "passkey_invalid_rpID_or_domain", message: error.localizedDescription)
    case .notHandled, .notInteractive:
      return ClerkJSPasskeyError(code: "passkey_operation_aborted", message: error.localizedDescription)
    default:
      return ClerkJSPasskeyError(code: failed, message: error.localizedDescription)
    }
  }
}

struct ClerkJSPasskeyCreateOptions: Equatable {
  var challenge: Data
  var relyingPartyID: String
  var userID: Data
  var displayName: String
  var excludeCredentials: [Data]
}

struct ClerkJSPasskeyGetOptions: Equatable {
  var challenge: Data
  var relyingPartyID: String
  var allowCredentials: [Data]
}

final class ClerkJSPasskeyCeremony: NSObject, @unchecked Sendable {
  private var controller: ASAuthorizationController?
  private var continuation: CheckedContinuation<ASAuthorization, Error>?

  func create(payload: String) async -> Result<String, ClerkJSPasskeyError> {
    switch Self.parseCreate(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let options):
      do {
        let authorization = try await performCreate(options)
        return Self.encodeRegistration(authorization)
      } catch {
        return .failure(.from(error, action: .create))
      }
    }
  }

  func get(payload: String) async -> Result<String, ClerkJSPasskeyError> {
    switch Self.parseGet(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let options):
      do {
        let authorization = try await performGet(options)
        return Self.encodeAssertion(authorization)
      } catch {
        return .failure(.from(error, action: .get))
      }
    }
  }

  func cancel() {
    Task { @MainActor [weak self] in
      self?.cancelOnMain()
    }
  }

  static func parseCreate(_ payload: String) -> Result<ClerkJSPasskeyCreateOptions, ClerkJSPasskeyError> {
    guard let object = jsonObject(payload) else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_registration_failed", message: "Invalid public key or RpID")
      )
    }
    guard let relyingPartyID = string(object["rpId"]), !relyingPartyID.isEmpty,
          let challenge = data(base64URL: string(object["challenge"]) ?? ""), !challenge.isEmpty,
          let userID = data(base64URL: string(object["userId"]) ?? ""), !userID.isEmpty
    else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_registration_failed", message: "Invalid public key or RpID")
      )
    }
    let excludeCredentials = (object["excludeCredentials"] as? [String] ?? []).compactMap { data(base64URL: $0) }
    return .success(
      ClerkJSPasskeyCreateOptions(
        challenge: challenge,
        relyingPartyID: relyingPartyID,
        userID: userID,
        displayName: string(object["displayName"]) ?? "",
        excludeCredentials: excludeCredentials
      )
    )
  }

  static func parseGet(_ payload: String) -> Result<ClerkJSPasskeyGetOptions, ClerkJSPasskeyError> {
    guard let object = jsonObject(payload) else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_retrieval_failed", message: "publicKeyCredential has not been provided")
      )
    }
    guard let relyingPartyID = string(object["rpId"]), !relyingPartyID.isEmpty,
          let challenge = data(base64URL: string(object["challenge"]) ?? ""), !challenge.isEmpty
    else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_retrieval_failed", message: "Invalid public key or RpID")
      )
    }
    let allowCredentials = (object["allowCredentials"] as? [String] ?? []).compactMap { data(base64URL: $0) }
    return .success(
      ClerkJSPasskeyGetOptions(
        challenge: challenge,
        relyingPartyID: relyingPartyID,
        allowCredentials: allowCredentials
      )
    )
  }

  static func registrationJSON(credentialID: Data, attestationObject: Data, clientDataJSON: Data) -> [String: Any] {
    let id = base64URL(from: credentialID)
    return [
      "id": id,
      "rawId": id,
      "type": "public-key",
      "authenticatorAttachment": "platform",
      "response": [
        "attestationObject": base64URL(from: attestationObject),
        "clientDataJSON": base64URL(from: clientDataJSON),
        "transports": ["internal"],
      ],
    ]
  }

  static func assertionJSON(
    credentialID: Data,
    authenticatorData: Data,
    clientDataJSON: Data,
    signature: Data,
    userID: Data
  ) -> [String: Any] {
    let id = base64URL(from: credentialID)
    return [
      "id": id,
      "rawId": id,
      "type": "public-key",
      "authenticatorAttachment": "platform",
      "response": [
        "authenticatorData": base64URL(from: authenticatorData),
        "clientDataJSON": base64URL(from: clientDataJSON),
        "signature": base64URL(from: signature),
        "userHandle": base64URL(from: userID),
      ],
    ]
  }

  static func base64URL(from data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))
  }

  static func data(base64URL: String) -> Data? {
    var base64 = base64URL
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let pad = base64.count % 4
    if pad != 0 {
      base64.append(String(repeating: "=", count: 4 - pad))
    }
    return Data(base64Encoded: base64)
  }

  private static func encodeRegistration(_ authorization: ASAuthorization) -> Result<String, ClerkJSPasskeyError> {
    guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
          let attestationObject = credential.rawAttestationObject
    else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_registration_failed", message: "Not valid registration result")
      )
    }
    return encodeJSON(
      registrationJSON(
        credentialID: credential.credentialID,
        attestationObject: attestationObject,
        clientDataJSON: credential.rawClientDataJSON
      ),
      action: .create
    )
  }

  private static func encodeAssertion(_ authorization: ASAuthorization) -> Result<String, ClerkJSPasskeyError> {
    guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
      return .failure(
        ClerkJSPasskeyError(code: "passkey_retrieval_failed", message: "Could not retrieve passkey")
      )
    }
    return encodeJSON(
      assertionJSON(
        credentialID: credential.credentialID,
        authenticatorData: credential.rawAuthenticatorData,
        clientDataJSON: credential.rawClientDataJSON,
        signature: credential.signature,
        userID: credential.userID
      ),
      action: .get
    )
  }

  private static func encodeJSON(_ object: [String: Any], action: ClerkJSPasskeyAction) -> Result<String, ClerkJSPasskeyError> {
    let failed = switch action {
    case .create:
      "passkey_registration_failed"
    case .get:
      "passkey_retrieval_failed"
    }
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let text = String(data: data, encoding: .utf8)
    else {
      return .failure(ClerkJSPasskeyError(code: failed, message: "Failed to encode credential"))
    }
    return .success(text)
  }

  private static func jsonObject(_ payload: String) -> [String: Any]? {
    guard let data = payload.data(using: .utf8) else {
      return nil
    }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  private static func string(_ value: Any?) -> String? {
    value as? String
  }

  @MainActor
  private func performCreate(_ options: ClerkJSPasskeyCreateOptions) async throws -> ASAuthorization {
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.relyingPartyID)
    let request = provider.createCredentialRegistrationRequest(
      challenge: options.challenge,
      name: options.displayName,
      userID: options.userID
    )
    if #available(iOS 17.4, *) {
      request.excludedCredentials = options.excludeCredentials.map {
        ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
      }
    }
    return try await perform(request)
  }

  @MainActor
  private func performGet(_ options: ClerkJSPasskeyGetOptions) async throws -> ASAuthorization {
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.relyingPartyID)
    let request = provider.createCredentialAssertionRequest(challenge: options.challenge)
    request.allowedCredentials = options.allowCredentials.map {
      ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
    }
    return try await perform(request)
  }

  @MainActor
  private func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
    cancelOnMain()
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      self.controller = controller
      controller.performRequests()
    }
  }

  @MainActor
  private func cancelOnMain() {
    controller?.cancel()
    controller = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(throwing: CancellationError())
  }

  @MainActor
  private func complete(with authorization: ASAuthorization) {
    controller = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(returning: authorization)
  }

  @MainActor
  private func complete(with error: Error) {
    controller = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(throwing: error)
  }
}

extension ClerkJSPasskeyCeremony: ASAuthorizationControllerDelegate {
  @MainActor
  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    complete(with: authorization)
  }

  @MainActor
  func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
    complete(with: error)
  }
}

extension ClerkJSPasskeyCeremony: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    #if canImport(UIKit) && !os(macOS)
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    #elseif canImport(AppKit)
    return NSApplication.shared.keyWindow
      ?? NSApplication.shared.mainWindow
      ?? NSApplication.shared.windows.first
      ?? ASPresentationAnchor()
    #else
    return ASPresentationAnchor()
    #endif
  }
}
#endif
