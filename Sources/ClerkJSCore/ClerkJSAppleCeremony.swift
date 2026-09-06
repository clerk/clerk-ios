import Foundation

public struct AppleIdentityToken: Equatable, Sendable {
  public var identityToken: String
  public var firstName: String?
  public var lastName: String?

  public init(identityToken: String, firstName: String? = nil, lastName: String? = nil) {
    self.identityToken = identityToken
    self.firstName = firstName
    self.lastName = lastName
  }

  var json: String {
    var object: [String: Any] = ["identityToken": identityToken]
    if let firstName {
      object["firstName"] = firstName
    }
    if let lastName {
      object["lastName"] = lastName
    }
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let text = String(data: data, encoding: .utf8)
    else {
      return "{\"identityToken\":\"\"}"
    }
    return text
  }
}

#if !os(watchOS)
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ClerkJSAppleScope: String, Equatable {
  case email
  case fullName
}

struct ClerkJSAppleRequest: Equatable {
  var nonce: String
  var scopes: [ClerkJSAppleScope]

  var authorizationScopes: [ASAuthorization.Scope] {
    scopes.map { scope in
      switch scope {
      case .email:
        .email
      case .fullName:
        .fullName
      }
    }
  }
}

struct ClerkJSAppleError: Error, Equatable {
  var code: String
  var message: String

  var json: String {
    let payload = ["code": code, "message": message]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8)
    else {
      return "{\"code\":\"apple_failed\",\"message\":\"Sign in with Apple failed\"}"
    }
    return text
  }

  static let cancelled = ClerkJSAppleError(
    code: "apple_cancelled",
    message: "The user cancelled Sign in with Apple."
  )
  static let invalidPayload = ClerkJSAppleError(
    code: "apple_invalid_payload",
    message: "Invalid Apple identity token payload"
  )

  static func from(_ error: Error) -> ClerkJSAppleError {
    if let apple = error as? ClerkJSAppleError {
      return apple
    }
    if error is CancellationError {
      return .cancelled
    }
    let nsError = error as NSError
    if nsError.domain == ASAuthorizationError.errorDomain,
       let code = ASAuthorizationError.Code(rawValue: nsError.code),
       code == .canceled
    {
      return .cancelled
    }
    return ClerkJSAppleError(code: "apple_failed", message: error.localizedDescription)
  }
}

final class ClerkJSAppleCeremony: NSObject, @unchecked Sendable {
  typealias Performer = @MainActor (ClerkJSAppleRequest) async throws -> AppleIdentityToken

  var performer: Performer?
  private var controller: ASAuthorizationController?
  private var continuation: CheckedContinuation<AppleIdentityToken, Error>?

  func start(payload: String) async -> Result<AppleIdentityToken, ClerkJSAppleError> {
    switch Self.parse(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let request):
      do {
        let identity = try await perform(request)
        return Self.validated(identity)
      } catch {
        return .failure(.from(error))
      }
    }
  }

  func cancel() {
    Task { @MainActor [weak self] in
      self?.cancelOnMain()
    }
  }

  static func parse(_ payload: String) -> Result<ClerkJSAppleRequest, ClerkJSAppleError> {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return .success(ClerkJSAppleRequest(nonce: newNonce(), scopes: defaultScopes))
    }
    guard let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return .failure(.invalidPayload)
    }
    let nonce: String
    if let raw = object["nonce"] as? String {
      nonce = raw.isEmpty ? newNonce() : raw
    } else if object["nonce"] == nil {
      nonce = newNonce()
    } else {
      return .failure(.invalidPayload)
    }
    let scopes: [ClerkJSAppleScope]
    if object["scopes"] == nil {
      scopes = defaultScopes
    } else if let names = object["scopes"] as? [String] {
      var parsed: [ClerkJSAppleScope] = []
      parsed.reserveCapacity(names.count)
      for name in names {
        guard let scope = ClerkJSAppleScope(rawValue: name) else {
          return .failure(.invalidPayload)
        }
        parsed.append(scope)
      }
      scopes = parsed
    } else {
      return .failure(.invalidPayload)
    }
    return .success(ClerkJSAppleRequest(nonce: nonce, scopes: scopes))
  }

  static func validated(_ identity: AppleIdentityToken) -> Result<AppleIdentityToken, ClerkJSAppleError> {
    let token = identity.identityToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      return .failure(.invalidPayload)
    }
    return .success(
      AppleIdentityToken(
        identityToken: token,
        firstName: trimmedName(identity.firstName),
        lastName: trimmedName(identity.lastName)
      )
    )
  }

  static func identity(from credential: ASAuthorizationAppleIDCredential) -> Result<AppleIdentityToken, ClerkJSAppleError> {
    let token = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    return validated(
      AppleIdentityToken(
        identityToken: token,
        firstName: credential.fullName?.givenName,
        lastName: credential.fullName?.familyName
      )
    )
  }

  private static let defaultScopes: [ClerkJSAppleScope] = [.fullName, .email]

  private static func newNonce() -> String {
    UUID().uuidString.lowercased()
  }

  private static func trimmedName(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  @MainActor
  private func perform(_ request: ClerkJSAppleRequest) async throws -> AppleIdentityToken {
    cancelOnMain()
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      if let performer {
        Task { @MainActor in
          do {
            try await self.complete(with: performer(request))
          } catch {
            self.complete(with: error)
          }
        }
        return
      }
      startAuthorization(request)
    }
  }

  @MainActor
  private func startAuthorization(_ request: ClerkJSAppleRequest) {
    let provider = ASAuthorizationAppleIDProvider()
    let appleRequest = provider.createRequest()
    appleRequest.requestedScopes = request.authorizationScopes
    appleRequest.nonce = request.nonce
    let controller = ASAuthorizationController(authorizationRequests: [appleRequest])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.controller = controller
    controller.performRequests()
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
  private func complete(with identity: AppleIdentityToken) {
    controller = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(returning: identity)
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

extension ClerkJSAppleCeremony: ASAuthorizationControllerDelegate {
  @MainActor
  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      complete(with: ClerkJSAppleError.invalidPayload)
      return
    }
    switch Self.identity(from: credential) {
    case .success(let identity):
      complete(with: identity)
    case .failure(let error):
      complete(with: error)
    }
  }

  @MainActor
  func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
    complete(with: error)
  }
}

extension ClerkJSAppleCeremony: ASAuthorizationControllerPresentationContextProviding {
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
