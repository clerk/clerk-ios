import ClerkJSCore
import ClerkSnapshots
import Foundation

@MainActor
private final class ClerkExternalEngineSlot { var engine: ClerkExternalEngine? }

@MainActor
final class ClerkExternalEngine: ClerkEngineClient {
  let runtimeID: String
  private let scope: ClerkRuntimeScope
  private let remoteInvoke: @MainActor @Sendable (Data) async throws -> Data
  private let capabilities = ClerkJSPlatformCapabilities()
  private let storage: ClerkJSSecureStorage
  private let biometricCredential: ClerkJSNativeCapability
  private var disposed = false
  private var revision: UInt64 = 0
  private var tokenEventSequence: UInt64 = 0
  private var expectedIdentityGeneration: ClientResponseGeneration
  private var publication: Task<Void, Error>?
  private var requests: [UUID: Task<Data, Error>] = [:]

  init(kit: Clerk, runtimeID: String, invoke: @escaping @MainActor @Sendable (Data) async throws -> Data) {
    self.runtimeID = runtimeID
    scope = kit.runtimeScope
    remoteInvoke = invoke
    storage = ClerkJSHostStore.secureStorage(for: kit)
    biometricCredential = ClerkJSHostStore.biometricCredential(for: kit)
    expectedIdentityGeneration = kit.clientResponseGeneration
  }

  func validate() throws {
    guard !disposed, try scope.requireCurrentClerk().clientResponseGeneration == expectedIdentityGeneration else {
      throw CancellationError()
    }
  }

  func publish(_ data: Data) async throws {
    let state = try JSONDecoder().decode(ClerkJSState.self, from: data)
    guard state.protocolVersion == 1, state.generation == runtimeID else { throw CancellationError() }
    let previous = publication
    let task = Task { @MainActor in
      try await previous?.value
      try validate()
      guard state.revision > revision else { return }
      let kit = try scope.requireCurrentClerk()
      try await kit.applyEngineState(state, scope: scope) { try self.validate() }
      expectedIdentityGeneration = kit.clientResponseGeneration
      revision = state.revision
      if let event = state.tokenEvent, event.sequence > tokenEventSequence {
        tokenEventSequence = event.sequence
        if kit.session?.id == event.sessionId { kit.auth.send(.tokenRefreshed(token: event.jwt)) }
      }
    }
    publication = task
    try await task.value
  }

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    try validate()
    if invocation.receiver == .clerk, ["initialize", "setApplicationActive"].contains(invocation.method) {
      return .null
    }
    let kit = try scope.requireCurrentClerk()
    let guarded = try ClerkJSInvocation(
      receiver: .clerk,
      method: "invokeForIdentity",
      arguments: [
        JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(invocation)),
        .object(["clientId": kit.client.map { .string($0.id) } ?? .null, "sessionId": kit.session.map { .string($0.id) } ?? .null]),
      ]
    )
    struct Reply: Decodable { let result: JSONValue?; let error: ClerkJSError? }
    let requestID = UUID()
    let payload = try JSONEncoder().encode(guarded)
    let task = Task { try await remoteInvoke(payload) }
    requests[requestID] = task
    defer { requests[requestID] = nil }
    let data = try await withTaskCancellationHandler {
      try await task.value
    } onCancel: { task.cancel() }
    try validate()
    let reply = try JSONDecoder().decode(Reply.self, from: data)
    if let error = reply.error { throw KitJSErrorMapping.kitError(error) }
    return reply.result ?? .null
  }

  func performCapability(_ action: String, payload: Data) async throws -> Data {
    try validate()
    if action == "biometricCredential" {
      return try await JSONEncoder().encode(biometricCredential(JSONDecoder().decode(JSONValue.self, from: payload)))
    }
    if action == "storage" {
      do {
        return try await storage.perform(payload)
      } catch DecodingError.dataCorrupted(let context) where context.codingPath.last?.stringValue == "operation" {
        throw ClerkClientError(message: "Unsupported native storage operation.")
      }
    }
    let result = try await capabilities.perform(action, payload: String(decoding: payload, as: UTF8.self))
    try validate()
    return Data(result.utf8)
  }

  func invalidate() {
    disposed = true
    publication?.cancel()
    for request in requests.values {
      request.cancel()
    }
    requests.removeAll()
    capabilities.cancel()
  }

  func dispose() async {
    invalidate()
    _ = try? await biometricCredential(.object(["operation": .string("dispose")]))
  }
}

extension Clerk {
  @_spi(ClerkExpo)
  public static func configureExternalRuntime(
    publishableKey: String,
    options: Clerk.Options = .init(),
    runtimeID: String,
    initialState: Data,
    invoke: @escaping @MainActor @Sendable (Data) async throws -> Data
  ) async throws {
    let state = try JSONDecoder().decode(ClerkJSState.self, from: initialState)
    guard state.protocolVersion == 1, state.generation == runtimeID else { throw CancellationError() }
    let slot = ClerkExternalEngineSlot()
    makeEngineClient = { kit in
      if let engine = slot.engine { return engine }
      let engine = ClerkExternalEngine(kit: kit, runtimeID: runtimeID, invoke: invoke)
      slot.engine = engine
      return engine
    }
    _ = try await reconfigure(publishableKey: publishableKey, options: options)
    guard let engine = await resolvedEngineClient() as? ClerkExternalEngine else { throw CancellationError() }
    try await engine.publish(initialState)
  }

  @_spi(ClerkExpo)
  public static func publishExternalRuntimeState(runtimeID: String, state: Data) async throws {
    guard let engine = engineClient as? ClerkExternalEngine, engine.runtimeID == runtimeID else { throw CancellationError() }
    try await engine.publish(state)
  }

  @_spi(ClerkExpo)
  public static func detachExternalRuntime(runtimeID: String) async {
    guard let engine = engineClient as? ClerkExternalEngine, engine.runtimeID == runtimeID else { return }
    await disposeEngine()
  }

  @_spi(ClerkExpo)
  public static func performExternalRuntimeCapability(runtimeID: String, action: String, payload: Data) async throws -> Data {
    guard let engine = engineClient as? ClerkExternalEngine, engine.runtimeID == runtimeID else { throw CancellationError() }
    do {
      let result = try await engine.performCapability(action, payload: payload)
      return Data("{\"result\":".utf8) + result + Data("}".utf8)
    } catch {
      return Data("{\"error\":".utf8) + ClerkJSPlatformCapabilities.errorJSON(error) + Data("}".utf8)
    }
  }
}
