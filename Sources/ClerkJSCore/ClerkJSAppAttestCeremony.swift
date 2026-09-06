import Foundation

public struct DeviceAttestParams: Equatable, Sendable {
  public var clientDataHash: Data

  public init(clientDataHash: Data) {
    self.clientDataHash = clientDataHash
  }

  var json: String {
    DeviceAttestationProof.encode(["clientDataHash": clientDataHash.base64EncodedString()])
      ?? "{}"
  }
}

public struct DeviceAttestationProof: Equatable, Sendable {
  public var keyId: String
  public var attestation: Data

  public init(keyId: String, attestation: Data) {
    self.keyId = keyId
    self.attestation = attestation
  }

  var json: String {
    Self.encode([
      "keyId": keyId,
      "attestation": attestation.base64EncodedString(),
    ]) ?? "{\"keyId\":\"\",\"attestation\":\"\"}"
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

public struct DeviceAssertionProof: Equatable, Sendable {
  public var keyId: String
  public var assertion: Data

  public init(keyId: String, assertion: Data) {
    self.keyId = keyId
    self.assertion = assertion
  }

  var json: String {
    DeviceAttestationProof.encode([
      "keyId": keyId,
      "assertion": assertion.base64EncodedString(),
    ]) ?? "{\"keyId\":\"\",\"assertion\":\"\"}"
  }
}

public struct ClerkJSAppAttestKeyIdStore: Sendable {
  public var get: @Sendable () async -> String?
  public var set: @Sendable (String) async -> Void
  public var delete: @Sendable () async -> Void

  public init(
    get: @escaping @Sendable () async -> String?,
    set: @escaping @Sendable (String) async -> Void,
    delete: @escaping @Sendable () async -> Void
  ) {
    self.get = get
    self.set = set
    self.delete = delete
  }

  public static func memory() -> ClerkJSAppAttestKeyIdStore {
    let box = MemoryKeyIdBox()
    return ClerkJSAppAttestKeyIdStore(
      get: { await box.get() },
      set: { await box.set($0) },
      delete: { await box.delete() }
    )
  }

  public static func keychain(service: String, account: String = "attest-key-id") -> ClerkJSAppAttestKeyIdStore {
    let box = KeychainKeyIdBox(keychain: ClerkJSKeychain(service: service), account: account)
    return ClerkJSAppAttestKeyIdStore(
      get: { await box.get() },
      set: { await box.set($0) },
      delete: { await box.delete() }
    )
  }
}

private actor MemoryKeyIdBox {
  var keyId: String?

  func get() -> String? {
    keyId
  }

  func set(_ keyId: String) {
    self.keyId = keyId
  }

  func delete() {
    keyId = nil
  }
}

private actor KeychainKeyIdBox {
  let keychain: ClerkJSKeychain
  let account: String
  var memory: String?

  init(keychain: ClerkJSKeychain, account: String) {
    self.keychain = keychain
    self.account = account
  }

  func get() -> String? {
    if let data = try? keychain.data(account: account),
       let stored = String(data: data, encoding: .utf8),
       !stored.isEmpty
    {
      memory = stored
      return stored
    }
    return memory
  }

  func set(_ keyId: String) {
    memory = keyId
    if keyId.isEmpty {
      try? keychain.delete(account: account)
    } else {
      try? keychain.set(Data(keyId.utf8), account: account)
    }
  }

  func delete() {
    memory = nil
    try? keychain.delete(account: account)
  }
}

#if !os(watchOS)
#if canImport(DeviceCheck)
@preconcurrency import DeviceCheck
#endif

struct ClerkJSAppAttestRequest: Equatable {
  var clientDataHash: Data
}

struct ClerkJSAppAttestError: Error, Equatable {
  var code: String
  var message: String

  var json: String {
    DeviceAttestationProof.encode(["code": code, "message": message])
      ?? "{\"code\":\"device_attest_failed\",\"message\":\"App Attest failed.\"}"
  }

  static let cancelled = ClerkJSAppAttestError(
    code: "device_attest_cancelled",
    message: "App Attest was canceled."
  )
  static let unavailable = ClerkJSAppAttestError(
    code: "device_attest_unavailable",
    message: "App Attest is not available on this device."
  )
  static let missingKey = ClerkJSAppAttestError(
    code: "device_attest_missing_key",
    message: "No App Attest key ID is stored. Prepare attestation first."
  )
  static let failed = ClerkJSAppAttestError(
    code: "device_attest_failed",
    message: "App Attest failed."
  )
  static let invalidPayload = ClerkJSAppAttestError(
    code: "device_attest_invalid_payload",
    message: "Invalid App Attest payload"
  )

  static func from(_ error: Error) -> ClerkJSAppAttestError {
    if let attest = error as? ClerkJSAppAttestError {
      return attest
    }
    if error is CancellationError {
      return .cancelled
    }
    #if canImport(DeviceCheck)
    let nsError = error as NSError
    if nsError.domain == DCError.errorDomain, let code = DCError.Code(rawValue: nsError.code) {
      switch code {
      case .featureUnsupported:
        return .unavailable
      case .invalidKey:
        return .missingKey
      case .invalidInput:
        return .invalidPayload
      case .serverUnavailable, .unknownSystemFailure:
        return ClerkJSAppAttestError(code: failed.code, message: error.localizedDescription)
      @unknown default:
        return ClerkJSAppAttestError(code: failed.code, message: error.localizedDescription)
      }
    }
    #endif
    return ClerkJSAppAttestError(code: failed.code, message: error.localizedDescription)
  }
}

final class ClerkJSAppAttestCeremony: @unchecked Sendable {
  typealias AttestPerformer = @MainActor (ClerkJSAppAttestRequest) async throws -> DeviceAttestationProof
  typealias AssertPerformer = @MainActor (ClerkJSAppAttestRequest) async throws -> DeviceAssertionProof

  var keyIdStore: ClerkJSAppAttestKeyIdStore
  var attestPerformer: AttestPerformer?
  var assertPerformer: AssertPerformer?
  private var attestContinuation: CheckedContinuation<DeviceAttestationProof, Error>?
  private var assertContinuation: CheckedContinuation<DeviceAssertionProof, Error>?

  init(keyIdStore: ClerkJSAppAttestKeyIdStore = .memory()) {
    self.keyIdStore = keyIdStore
  }

  func attest(payload: String) async -> Result<DeviceAttestationProof, ClerkJSAppAttestError> {
    switch Self.parse(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let request):
      do {
        let proof = try await Self.validated(performAttest(request))
        await keyIdStore.set(proof.keyId)
        return .success(proof)
      } catch {
        return .failure(.from(error))
      }
    }
  }

  func assert(payload: String) async -> Result<DeviceAssertionProof, ClerkJSAppAttestError> {
    switch Self.parse(payload) {
    case .failure(let error):
      return .failure(error)
    case .success(let request):
      do {
        return try await .success(Self.validated(performAssert(request)))
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

  static func parse(_ payload: String) -> Result<ClerkJSAppAttestRequest, ClerkJSAppAttestError> {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return .failure(.invalidPayload)
    }
    guard let raw = object["clientDataHash"] as? String else {
      return .failure(.invalidPayload)
    }
    let hashText = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let hash = Data(base64Encoded: hashText), hash.count == 32 else {
      return .failure(.invalidPayload)
    }
    return .success(ClerkJSAppAttestRequest(clientDataHash: hash))
  }

  static func validated(_ proof: DeviceAttestationProof) throws -> DeviceAttestationProof {
    let keyId = proof.keyId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyId.isEmpty, !proof.attestation.isEmpty else {
      throw ClerkJSAppAttestError.invalidPayload
    }
    return DeviceAttestationProof(keyId: keyId, attestation: proof.attestation)
  }

  static func validated(_ proof: DeviceAssertionProof) throws -> DeviceAssertionProof {
    let keyId = proof.keyId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyId.isEmpty, !proof.assertion.isEmpty else {
      throw ClerkJSAppAttestError.invalidPayload
    }
    return DeviceAssertionProof(keyId: keyId, assertion: proof.assertion)
  }

  @MainActor
  private func performAttest(_ request: ClerkJSAppAttestRequest) async throws -> DeviceAttestationProof {
    cancelOnMain()
    return try await withCheckedThrowingContinuation { continuation in
      self.attestContinuation = continuation
      if let attestPerformer {
        Task { @MainActor in
          do {
            try await self.completeAttest(with: attestPerformer(request))
          } catch {
            self.completeAttest(with: error)
          }
        }
        return
      }
      startAttestation(request)
    }
  }

  @MainActor
  private func performAssert(_ request: ClerkJSAppAttestRequest) async throws -> DeviceAssertionProof {
    cancelOnMain()
    return try await withCheckedThrowingContinuation { continuation in
      self.assertContinuation = continuation
      if let assertPerformer {
        Task { @MainActor in
          do {
            try await self.completeAssert(with: assertPerformer(request))
          } catch {
            self.completeAssert(with: error)
          }
        }
        return
      }
      Task { @MainActor in
        await self.startAssertion(request)
      }
    }
  }

  @MainActor
  private func startAttestation(_ request: ClerkJSAppAttestRequest) {
    #if canImport(DeviceCheck)
    guard DCAppAttestService.shared.isSupported else {
      completeAttest(with: ClerkJSAppAttestError.unavailable)
      return
    }
    Task { @MainActor in
      do {
        let keyId = try await DCAppAttestService.shared.generateKey()
        let attestation = try await DCAppAttestService.shared.attestKey(
          keyId,
          clientDataHash: request.clientDataHash
        )
        self.completeAttest(with: DeviceAttestationProof(keyId: keyId, attestation: attestation))
      } catch {
        self.completeAttest(with: error)
      }
    }
    #else
    completeAttest(with: ClerkJSAppAttestError.unavailable)
    #endif
  }

  @MainActor
  private func startAssertion(_ request: ClerkJSAppAttestRequest) async {
    guard let keyId = await keyIdStore.get(), !keyId.isEmpty else {
      completeAssert(with: ClerkJSAppAttestError.missingKey)
      return
    }
    #if canImport(DeviceCheck)
    guard DCAppAttestService.shared.isSupported else {
      completeAssert(with: ClerkJSAppAttestError.unavailable)
      return
    }
    do {
      let assertion = try await DCAppAttestService.shared.generateAssertion(
        keyId,
        clientDataHash: request.clientDataHash
      )
      completeAssert(with: DeviceAssertionProof(keyId: keyId, assertion: assertion))
    } catch {
      completeAssert(with: error)
    }
    #else
    completeAssert(with: ClerkJSAppAttestError.unavailable)
    #endif
  }

  @MainActor
  private func cancelOnMain() {
    if let attestContinuation {
      self.attestContinuation = nil
      attestContinuation.resume(throwing: CancellationError())
    }
    if let assertContinuation {
      self.assertContinuation = nil
      assertContinuation.resume(throwing: CancellationError())
    }
  }

  @MainActor
  private func completeAttest(with proof: DeviceAttestationProof) {
    guard let attestContinuation else {
      return
    }
    self.attestContinuation = nil
    attestContinuation.resume(returning: proof)
  }

  @MainActor
  private func completeAttest(with error: Error) {
    guard let attestContinuation else {
      return
    }
    self.attestContinuation = nil
    attestContinuation.resume(throwing: error)
  }

  @MainActor
  private func completeAssert(with proof: DeviceAssertionProof) {
    guard let assertContinuation else {
      return
    }
    self.assertContinuation = nil
    assertContinuation.resume(returning: proof)
  }

  @MainActor
  private func completeAssert(with error: Error) {
    guard let assertContinuation else {
      return
    }
    self.assertContinuation = nil
    assertContinuation.resume(throwing: error)
  }
}
#endif
