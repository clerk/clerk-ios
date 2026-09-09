#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
import Foundation

@MainActor public final class AppleAuthentication: NSObject {
  public typealias Anchor = @MainActor () -> ASPresentationAnchor
  typealias BrowserFactory = @MainActor (URL, URL, @escaping ASWebAuthenticationSession.CompletionHandler) throws -> ASWebAuthenticationSession
  private let anchor: Anchor
  private let makeBrowser: BrowserFactory
  private var browser: ASWebAuthenticationSession?
  private var browserID: UUID?
  private var browserCompletion: CheckedContinuation<JSONValue, any Error>?
  private var credentialFailureCode = "passkey_failed"
  private var credentialController: ASAuthorizationController?
  private var credentialID: UUID?
  private var credentialCompletion: CheckedContinuation<JSONValue, any Error>?
  public convenience init(anchor: @escaping Anchor) {
    self.init(anchor: anchor, makeBrowser: Self.makeSystemBrowser)
  }

  init(anchor: @escaping Anchor, makeBrowser: @escaping BrowserFactory) {
    self.anchor = anchor
    self.makeBrowser = makeBrowser
  }

  private static func makeSystemBrowser(url: URL, callback: URL, completion: @escaping ASWebAuthenticationSession.CompletionHandler) throws -> ASWebAuthenticationSession {
    if callback.scheme?.lowercased() == "https" {
      guard #available(iOS 17.4, macOS 14.4, visionOS 1.1, *), let host = callback.host else {
        throw CoreError(code: "capability_unavailable:https_callback")
      }
      return ASWebAuthenticationSession(url: url, callback: .https(host: host, path: callback.path), completionHandler: completion)
    }
    return ASWebAuthenticationSession(url: url, callbackURLScheme: callback.scheme, completionHandler: completion)
  }

  public func openBrowser(_: String, arguments: JSONValue) async throws -> JSONValue {
    guard browser == nil else { throw CoreError(code: "presentation_in_progress") }
    let args = try arguments.object()
    let url = try (args["url"] ?? .undefined).url()
    let callback = try (args["callbackUrl"] ?? .undefined).url()
    guard url.scheme == "https", let scheme = callback.scheme?.lowercased(), !["http", "javascript", "data", "file", "about"].contains(scheme) else { throw CoreError(code: "invalid_callback_url") }
    let operationID = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        browserCompletion = continuation
        browserID = operationID
        let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] url, error in
          Task { @MainActor in
            guard let self, self.browserID == operationID else { return }
            let continuation = self.browserCompletion
            self.browserCompletion = nil; self.browser = nil; self.browserID = nil
            if let url { continuation?.resume(returning: .object(["callbackUrl": .string(url.absoluteString)])) }
            else { continuation?.resume(throwing: CoreError(code: (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin ? "user_cancelled" : "browser_authentication_failed")) }
          }
        }
        do {
          browser = try makeBrowser(url, callback, completion)
        } catch {
          browserCompletion = nil; browserID = nil
          continuation.resume(throwing: error); return
        }
        browser?.presentationContextProvider = self
        guard browser?.start() == true else {
          browser = nil; browserCompletion = nil; browserID = nil
          continuation.resume(throwing: CoreError(code: "browser_presentation_failed")); return
        }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.cancelBrowser(operationID) }
    }
  }

  private func cancelBrowser(_ operationID: UUID) {
    guard browserID == operationID else { return }
    let completion = browserCompletion
    browserCompletion = nil
    browserID = nil
    browser?.cancel(); browser = nil
    completion?.resume(throwing: CancellationError())
  }

  public func credential(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard credentialController == nil else { throw CoreError(code: "presentation_in_progress") }
    let args = try arguments.object()
    let challenge = try binary(args["challenge"] ?? .undefined)
    let request: ASAuthorizationRequest
    if capability == "passkeys.create" {
      let rp = try (args["rp"] ?? .undefined).object()
      let user = try (args["user"] ?? .undefined).object()
      let selection = try (args["authenticatorSelection"] ?? .object([:])).object()
      if let attachment = selection["authenticatorAttachment"], attachment != .string("platform") { throw CoreError(code: "capability_unavailable:security_key") }
      if let attestation = args["attestation"], attestation != .string("none") { throw CoreError(code: "capability_unavailable:passkey_attestation") }
      let algorithms = try (args["pubKeyCredParams"] ?? .undefined).array()
      guard algorithms.contains(where: { (try? $0.object()["alg"]) == .number(-7) }) else { throw CoreError(code: "capability_unavailable:passkey_algorithm") }
      let provider = try ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: (rp["id"] ?? .undefined).string())
      let registration = try provider.createCredentialRegistrationRequest(challenge: challenge, name: (user["name"] ?? .undefined).string(), userID: binary(user["id"] ?? .undefined))
      registration.displayName = try (user["displayName"] ?? user["name"] ?? .undefined).string()
      registration.userVerificationPreference = try preference(selection["userVerification"])
      let excluded = try (args["excludeCredentials"] ?? .array([])).array()
      if !excluded.isEmpty {
        #if !os(visionOS)
        if #available(iOS 17.4, macOS 14.0, *) {
          registration.excludedCredentials = try excluded.map { try ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: binary($0.object()["id"] ?? .undefined)) }
        } else { throw CoreError(code: "capability_unavailable:excluded_credentials") }
        #else
        throw CoreError(code: "capability_unavailable:excluded_credentials")
        #endif
      }
      request = registration
    } else if capability == "passkeys.get" {
      let provider = try ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: (args["rpId"] ?? .undefined).string())
      let assertion = provider.createCredentialAssertionRequest(challenge: challenge)
      assertion.userVerificationPreference = try preference(args["userVerification"])
      assertion.allowedCredentials = try (args["allowCredentials"] ?? .array([])).array().map { try ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: binary($0.object()["id"] ?? .undefined)) }
      request = assertion
    } else { throw CoreError(code: "capability_unavailable") }
    return try await authorize(
      request,
      failureCode: "passkey_failed",
      conditionalUI: args["conditionalUI"] == .bool(true),
      preferImmediatelyAvailableCredentials: args["preferImmediatelyAvailableCredentials"] == .bool(true)
    )
  }

  public func appleIdentity(_: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.email]
    if args["fullName"] == .bool(true) { request.requestedScopes?.append(.fullName) }
    return try await authorize(request, failureCode: "apple_identity_failed")
  }

  private func authorize(_ request: ASAuthorizationRequest, failureCode: String, conditionalUI: Bool = false, preferImmediatelyAvailableCredentials: Bool = false) async throws -> JSONValue {
    guard credentialController == nil else { throw CoreError(code: "presentation_in_progress") }
    let operationID = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        credentialCompletion = continuation
        credentialID = operationID
        credentialFailureCode = failureCode
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        credentialController = controller
        if conditionalUI {
          #if os(iOS) && !targetEnvironment(macCatalyst)
          controller.performAutoFillAssistedRequests()
          #else
          credentialCompletion = nil; credentialController = nil; credentialID = nil
          continuation.resume(throwing: CoreError(code: "capability_unavailable:passkeys.autofill"))
          #endif
        } else if preferImmediatelyAvailableCredentials {
          controller.performRequests(options: .preferImmediatelyAvailableCredentials)
        } else {
          controller.performRequests()
        }
      }
    } onCancel: { Task { @MainActor [weak self] in self?.cancelCredential(operationID) } }
  }

  private func preference(_ value: JSONValue?) throws -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
    let preference = try (value ?? .string("preferred")).string()
    guard ["required", "preferred", "discouraged"].contains(preference) else { throw CoreError.invalidValue }
    return .init(rawValue: preference)
  }

  private func binary(_ value: JSONValue) throws -> Data {
    let text = try (value.object()["base64url"] ?? .undefined).string()
    let normalized = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    guard let data = Data(base64Encoded: normalized + String(repeating: "=", count: (4 - normalized.count % 4) % 4)) else { throw CoreError.invalidValue }
    return data
  }

  private func encoded(_ data: Data) -> JSONValue {
    .string(data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: ""))
  }

  private func cancelCredential(_ operationID: UUID) {
    guard credentialID == operationID else { return }
    let completion = credentialCompletion
    credentialCompletion = nil
    credentialID = nil
    credentialController?.cancel(); credentialController = nil
    completion?.resume(throwing: CancellationError())
  }
}

extension AppleAuthentication: ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
  public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    anchor()
  }

  public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    anchor()
  }
}

extension AppleAuthentication: ASAuthorizationControllerDelegate {
  public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard controller === credentialController else { return }
    let completion = credentialCompletion
    credentialCompletion = nil; credentialController = nil; credentialID = nil
    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
      guard let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8), !token.isEmpty else {
        completion?.resume(throwing: CoreError(code: "invalid_credential_result")); return
      }
      var identity: [String: JSONValue] = ["token": .string(token)]
      if let firstName = credential.fullName?.givenName { identity["firstName"] = .string(firstName) }
      if let lastName = credential.fullName?.familyName { identity["lastName"] = .string(lastName) }
      completion?.resume(returning: .object(identity)); return
    }
    var result: [String: JSONValue] = ["type": .string("public-key"), "authenticatorAttachment": .string("platform")]
    if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration, let attestation = credential.rawAttestationObject {
      result["id"] = encoded(credential.credentialID); result["rawId"] = encoded(credential.credentialID)
      result["response"] = .object(["clientDataJSON": encoded(credential.rawClientDataJSON), "attestationObject": encoded(attestation), "transports": .array([.string("internal")])])
    } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
      result["id"] = encoded(credential.credentialID); result["rawId"] = encoded(credential.credentialID)
      result["response"] = .object(["clientDataJSON": encoded(credential.rawClientDataJSON), "authenticatorData": encoded(credential.rawAuthenticatorData), "signature": encoded(credential.signature), "userHandle": encoded(credential.userID)])
    } else { completion?.resume(throwing: CoreError(code: "invalid_credential_result")); return }
    completion?.resume(returning: .object(result))
  }

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
    guard controller === credentialController else { return }
    let completion = credentialCompletion
    credentialCompletion = nil; credentialController = nil; credentialID = nil
    completion?.resume(throwing: CoreError(code: (error as? ASAuthorizationError)?.code == .canceled ? "user_cancelled" : credentialFailureCode))
  }
}
#endif
