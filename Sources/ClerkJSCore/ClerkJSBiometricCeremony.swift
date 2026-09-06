import Foundation

public enum BiometryKind: String, Equatable, Sendable {
  case none
  case touchID
  case faceID
  case opticID
}

public enum BiometricPolicy: String, Equatable, Sendable {
  case biometryCurrentSet = "biometry_current_set"
  case biometryAny = "biometry_any"
  case biometryOrDevicePasscode = "biometry_or_device_passcode"
}

public struct BiometricPresence: Equatable, Sendable {
  public var isAvailable: Bool
  public var biometry: BiometryKind
  public var unavailableReason: String?

  public init(isAvailable: Bool, biometry: BiometryKind, unavailableReason: String? = nil) {
    self.isAvailable = isAvailable
    self.biometry = biometry
    self.unavailableReason = unavailableReason
  }

  var json: String {
    var object: [String: Any] = [
      "isAvailable": isAvailable,
      "biometry": biometry.rawValue,
    ]
    if let unavailableReason {
      object["unavailableReason"] = unavailableReason
    }
    return Self.encode(object) ?? "{\"isAvailable\":false,\"biometry\":\"none\"}"
  }

  fileprivate static func encode(_ object: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let text = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return text
  }
}

public struct BiometricAuthentication: Equatable, Sendable {
  public var biometry: BiometryKind

  public init(biometry: BiometryKind) {
    self.biometry = biometry
  }

  var json: String {
    BiometricPresence.encode(["biometry": biometry.rawValue]) ?? "{\"biometry\":\"none\"}"
  }
}

public struct BiometricPromptParams: Equatable, Sendable {
  public var policy: BiometricPolicy
  public var reason: String?

  public init(policy: BiometricPolicy = .biometryCurrentSet, reason: String? = nil) {
    self.policy = policy
    self.reason = reason
  }

  var json: String {
    var object: [String: Any] = ["policy": policy.rawValue]
    if let reason {
      object["reason"] = reason
    }
    return BiometricPresence.encode(object) ?? "{}"
  }
}

#if !os(watchOS)
#if canImport(LocalAuthentication)
@preconcurrency import LocalAuthentication
#endif

struct ClerkJSBiometricRequest: Equatable {
  var policy: BiometricPolicy
  var reason: String

  #if canImport(LocalAuthentication)
  var laPolicy: LAPolicy {
    switch policy {
    case .biometryCurrentSet, .biometryAny:
      // current-set vs any is Secure Enclave access control, not an LAPolicy
      .deviceOwnerAuthenticationWithBiometrics
    case .biometryOrDevicePasscode:
      .deviceOwnerAuthentication
    }
  }
  #endif
}

struct ClerkJSBiometricError: Error, Equatable {
  var code: String
  var message: String

  var json: String {
    let payload = ["code": code, "message": message]
    return BiometricPresence.encode(payload)
      ?? "{\"code\":\"biometric_authentication_failed\",\"message\":\"Biometric authentication failed.\"}"
  }

  static let cancelled = ClerkJSBiometricError(
    code: "biometric_authentication_canceled",
    message: "Biometric authentication was canceled."
  )
  static let unavailable = ClerkJSBiometricError(
    code: "biometric_authentication_unavailable",
    message: "Biometric authentication is not available or not enrolled on this device."
  )
  static let failed = ClerkJSBiometricError(
    code: "biometric_authentication_failed",
    message: "Biometric authentication failed."
  )
  static let invalidPayload = ClerkJSBiometricError(
    code: "biometric_invalid_payload",
    message: "Invalid biometric payload"
  )

  static func from(_ error: Error) -> ClerkJSBiometricError {
    if let biometric = error as? ClerkJSBiometricError {
      return biometric
    }
    if error is CancellationError {
      return .cancelled
    }
    #if canImport(LocalAuthentication)
    let nsError = error as NSError
    if nsError.domain == LAError.errorDomain, let code = LAError.Code(rawValue: nsError.code) {
      switch code {
      case .userCancel, .appCancel, .systemCancel, .userFallback:
        return .cancelled
      case .authenticationFailed:
        return .failed
      case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout, .passcodeNotSet,
           .touchIDNotAvailable, .touchIDNotEnrolled, .touchIDLockout, .invalidContext, .notInteractive:
        return .unavailable
      default:
        return ClerkJSBiometricError(code: failed.code, message: error.localizedDescription)
      }
    }
    #endif
    return ClerkJSBiometricError(code: failed.code, message: error.localizedDescription)
  }
}

final class ClerkJSBiometricCeremony: @unchecked Sendable {
  typealias PresenceReader = @MainActor (ClerkJSBiometricRequest) -> BiometricPresence
  typealias Performer = @MainActor (ClerkJSBiometricRequest) async throws -> BiometricAuthentication

  var presenceReader: PresenceReader?
  var performer: Performer?
  #if canImport(LocalAuthentication)
  private var context: LAContext?
  #endif
  private var continuation: CheckedContinuation<BiometricAuthentication, Error>?

  func presence(payload: String) async -> Result<BiometricPresence, ClerkJSBiometricError> {
    switch Self.parse(payload) {
    case .failure(let error):
      .failure(error)
    case .success(let request):
      await .success(readPresence(request))
    }
  }

  func prompt(payload: String) async -> Result<BiometricAuthentication, ClerkJSBiometricError> {
    switch Self.parse(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let request):
      do {
        return try await .success(perform(request))
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

  static func parse(_ payload: String) -> Result<ClerkJSBiometricRequest, ClerkJSBiometricError> {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return .success(ClerkJSBiometricRequest(policy: .biometryCurrentSet, reason: defaultReason))
    }
    guard let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return .failure(.invalidPayload)
    }
    let policy: BiometricPolicy
    if object["policy"] == nil {
      policy = .biometryCurrentSet
    } else if let raw = object["policy"] as? String, let parsed = BiometricPolicy(rawValue: raw) {
      policy = parsed
    } else {
      return .failure(.invalidPayload)
    }
    let reason: String
    if object["reason"] == nil {
      reason = defaultReason
    } else if let raw = object["reason"] as? String {
      let trimmedReason = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      reason = trimmedReason.isEmpty ? defaultReason : trimmedReason
    } else {
      return .failure(.invalidPayload)
    }
    return .success(ClerkJSBiometricRequest(policy: policy, reason: reason))
  }

  private static let defaultReason = "Verify your identity"

  private func readPresence(_ request: ClerkJSBiometricRequest) async -> BiometricPresence {
    if let presenceReader {
      return await presenceReader(request)
    }
    return await MainActor.run { Self.systemPresence(request) }
  }

  @MainActor
  private func perform(_ request: ClerkJSBiometricRequest) async throws -> BiometricAuthentication {
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
      startEvaluation(request)
    }
  }

  @MainActor
  private func startEvaluation(_ request: ClerkJSBiometricRequest) {
    #if canImport(LocalAuthentication)
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(request.laPolicy, error: &error) else {
      complete(with: error.map(ClerkJSBiometricError.from) ?? .unavailable)
      return
    }
    self.context = context
    context.evaluatePolicy(request.laPolicy, localizedReason: request.reason) { success, error in
      let biometry = BiometryKind(context.biometryType)
      let mapped = error.map(ClerkJSBiometricError.from)
      Task { @MainActor in
        if success {
          self.complete(with: BiometricAuthentication(biometry: biometry))
          return
        }
        self.complete(with: mapped ?? ClerkJSBiometricError.failed)
      }
    }
    #else
    complete(with: ClerkJSBiometricError.unavailable)
    #endif
  }

  @MainActor
  private func cancelOnMain() {
    #if canImport(LocalAuthentication)
    context?.invalidate()
    context = nil
    #endif
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(throwing: CancellationError())
  }

  @MainActor
  private func complete(with authentication: BiometricAuthentication) {
    #if canImport(LocalAuthentication)
    context = nil
    #endif
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(returning: authentication)
  }

  @MainActor
  private func complete(with error: Error) {
    #if canImport(LocalAuthentication)
    context = nil
    #endif
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(throwing: error)
  }

  @MainActor
  private static func systemPresence(_ request: ClerkJSBiometricRequest) -> BiometricPresence {
    #if canImport(LocalAuthentication)
    let context = LAContext()
    var error: NSError?
    let available = context.canEvaluatePolicy(request.laPolicy, error: &error)
    let biometry = BiometryKind(context.biometryType)
    if available {
      return BiometricPresence(isAvailable: true, biometry: biometry)
    }
    let mapped = error.map(ClerkJSBiometricError.from) ?? .unavailable
    return BiometricPresence(
      isAvailable: false,
      biometry: biometry,
      unavailableReason: mapped.code
    )
    #else
    return BiometricPresence(
      isAvailable: false,
      biometry: .none,
      unavailableReason: ClerkJSBiometricError.unavailable.code
    )
    #endif
  }
}

#if canImport(LocalAuthentication)
extension BiometryKind {
  init(_ type: LABiometryType) {
    switch type {
    case .touchID:
      self = .touchID
    case .faceID:
      self = .faceID
    case .opticID:
      self = .opticID
    case .none:
      self = .none
    @unknown default:
      self = .none
    }
  }
}
#endif
#endif
