import ClerkJSCore
import ClerkSnapshots
import Foundation

@MainActor
final class ClerkJSHostEngine: ClerkEngineClient {
  private let host: ClerkJSHost
  private let scope: ClerkRuntimeScope
  private var disposed = false
  private var tokenEventSequence: UInt64 = 0
  private var expectedIdentityGeneration: ClientResponseGeneration

  init(host: ClerkJSHost, kit: Clerk) {
    self.host = host
    scope = kit.runtimeScope
    expectedIdentityGeneration = kit.clientResponseGeneration
    let scope = scope
    host.onStateChange = { [weak self] state in
      guard let self, !self.disposed else { throw CancellationError() }
      let current = try scope.requireCurrentClerk()
      guard current.clientResponseGeneration == expectedIdentityGeneration else {
        invalidate()
        if Clerk.engineClient === self { _ = Clerk.detachEngine() }
        Task { await self.host.dispose() }
        throw CancellationError()
      }
      try await current.applyEngineState(state, scope: scope) { [weak self] in
        guard let self, !self.disposed else { throw CancellationError() }
      }
      expectedIdentityGeneration = current.clientResponseGeneration
      if let event = state.tokenEvent, event.sequence > tokenEventSequence {
        tokenEventSequence = event.sequence
        if current.session?.id == event.sessionId {
          current.auth.send(.tokenRefreshed(token: event.jwt))
        }
      }
    }
  }

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    guard !disposed else { throw CancellationError() }
    try scope.validateStableRuntime()
    do {
      try await host.load()
      let result = try await host.invoke(invocation)
      try scope.validateStableRuntime()
      return result
    } catch let error as ClerkJSError {
      throw KitJSErrorMapping.kitError(error)
    }
  }

  func validateIdentityGeneration() throws {
    guard !disposed, try scope.requireCurrentClerk().clientResponseGeneration == expectedIdentityGeneration else {
      throw CancellationError()
    }
  }

  func invalidate() {
    disposed = true
  }

  func dispose() async {
    invalidate()
    await host.dispose()
  }
}

@MainActor
package enum ClerkJSHostStore {
  package static func registerPreview(isSignedIn: Bool, publishableKey _: String, onto kit: Clerk) {
    if let environment = try? ClerkJSHost.snapshotEnvironmentJSON() {
      try? kit.applyEngineEnvironmentJSON(environment)
    }
    if isSignedIn, let data = try? ClerkJSHost.snapshotSignedInClient() {
      try? kit.applyEngineClientJSON(data)
    }
  }

  static func makeHost(for kit: Clerk, sessionConfiguration: URLSessionConfiguration? = nil) -> ClerkJSHost {
    // Persistence belongs to ClerkKit's complete identity transaction. The host's
    // cache callbacks only seed this realm; published states are its sole writer.
    let token = kit.identityController.currentDeviceToken ?? ""
    let resources = ClerkJSCachedResources(
      client: token.isEmpty ? nil : kit.client.flatMap { try? JSONEncoder.clerkEncoder.encode($0) },
      environment: kit.environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    )
    return ClerkJSHost(
      publishableKey: kit.publishableKey,
      tokenCache: .init(getToken: { token }, saveToken: { _ in }),
      resourceCache: .init(load: { resources }, save: { _ in }),
      secureStorage: secureStorage(for: kit),
      biometricCredential: biometricCredential(for: kit),
      oauthRedirectURL: URL(string: kit.options.redirectConfig.redirectUrl) ?? ClerkJSRuntime.defaultOAuthRedirectURL,
      proxyURL: kit.options.proxyUrl,
      sessionConfiguration: sessionConfiguration,
      httpMiddleware: httpMiddleware(for: kit)
    )
  }

  static func httpMiddleware(for kit: Clerk) -> ClerkJSHTTPMiddleware {
    let scope = kit.runtimeScope
    let middleware = kit.options.middleware
    return .init(
      prepare: { request in
        _ = try await scope.requireCurrentClerk()
        var request = request
        for hook in middleware.request {
          try await hook.prepare(&request)
          try Task.checkCancellation()
          _ = try await scope.requireCurrentClerk()
        }
        return request
      },
      validate: { response, data, request in
        _ = try await scope.requireCurrentClerk()
        for hook in middleware.response {
          try await hook.validate(response, data: data, for: request)
          try Task.checkCancellation()
          _ = try await scope.requireCurrentClerk()
        }
      }
    )
  }

  static func secureStorage(for kit: Clerk) -> ClerkJSSecureStorage {
    let scope = kit.runtimeScope
    return ClerkJSSecureStorage(
      read: { key in
        try await MainActor.run {
          let current = try scope.requireCurrentClerk()
          return try current.dependencies.appLocalKeychain.data(forKey: key).map { String(decoding: $0, as: UTF8.self) }
        }
      },
      write: { key, value in
        try await MainActor.run {
          let current = try scope.requireCurrentClerk()
          if let value { try current.dependencies.appLocalKeychain.set(Data(value.utf8), forKey: key) }
          else { try current.dependencies.appLocalKeychain.deleteItem(forKey: key) }
        }
      },
      compareAndSwap: { key, expected, value in
        try await MainActor.run {
          let current = try scope.requireCurrentClerk()
          let keychain = current.dependencies.appLocalKeychain
          guard try keychain.data(forKey: key).map({ String(decoding: $0, as: UTF8.self) }) == expected else { return false }
          if let value { try keychain.set(Data(value.utf8), forKey: key) }
          else { try keychain.deleteItem(forKey: key) }
          return true
        }
      }
    )
  }
}

enum KitJSErrorMapping {
  static func kitError(_ error: ClerkJSError) -> any Error {
    if error.code == "native_biometric_key_error", let payload = error.nativeError,
       let data = try? JSONEncoder().encode(payload),
       let native = try? JSONDecoder().decode(BiometricCredentialKeyManagerError.self, from: data)
    {
      return native
    }
    if let rawStage = error.stage, let stage = PasskeyAuthenticationFailure.Stage(rawValue: rawStage) {
      var cause = error
      cause.stage = nil
      return PasskeyAuthenticationFailure(stage: stage, underlyingError: kitError(cause))
    }
    switch error.kind {
    case .api:
      let first = error.errors.first ?? ClerkAPIError(
        code: error.code ?? "api_error",
        message: error.message
      )
      if let trace = error.clerkTraceId, first.clerkTraceId.isEmpty {
        first.clerkTraceId = trace
      }
      return first
    case .offline, .runtime, .resolution, .javascript:
      return ClerkClientError(message: String.LocalizationValue(stringLiteral: error.message))
    }
  }
}

extension Clerk {
  @MainActor
  static func installJSHostFactoryIfNeeded() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    #if os(watchOS)
    makeEngineClient = { kit in WatchOperationEngine(kit: kit) }
    #else
    makeEngineClient = { kit in
      let host = ClerkJSHostStore.makeHost(for: kit)
      return ClerkJSHostEngine(host: host, kit: kit)
    }
    #endif
  }
}

extension Clerk {
  func applyEngineState(
    _ state: ClerkJSState,
    scope: ClerkRuntimeScope,
    validate: @escaping @MainActor @Sendable () throws -> Void
  ) async throws {
    try validate()
    try scope.validateStableRuntime()
    // Loading publishes provisional snapshots before a client credential exists.
    guard state.status == "ready" || state.status == "degraded" else { return }
    let client = try state.client.map { try JSONDecoder.clerkDecoder.decode(Client.self, from: JSONEncoder().encode($0)) }
    let environment = try state.environment.map { try JSONDecoder.clerkDecoder.decode(Environment.self, from: JSONEncoder().encode($0)) }
    let token = Optional(state.clientToken).nilIfEmpty
    if client != nil, token == nil {
      throw ClerkClientError(message: "The JS client snapshot has no device credential.")
    }
    let identity = ClerkIdentitySnapshot(
      state: client == nil ? .cleared : .present,
      deviceToken: token,
      client: client,
      serverDate: nil
    )
    let operation = try identityController.submitExternalTransition {
      try validate()
      try scope.validateStableRuntime()
      return .init(identity: identity, fenceAllClientResponses: false)
    }
    try await operation?.value
    try validate()
    try scope.validateStableRuntime()
    guard self.client == client, identityController.currentDeviceToken == token else {
      throw CancellationError()
    }
    self.environment = environment
  }
}

enum ClerkEngineAuthorization {
  static func evaluate(session: Session, params: CheckAuthorizationParams) -> Bool {
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .millisecondsSince1970
      let data = try ClerkJSAuthorization.evaluate("checkSessionAuthorization", arguments: [encoder.encode(session), encoder.encode(params)])
      return try JSONDecoder().decode(Bool.self, from: data)
    } catch {
      ClerkLogger.logError(error, message: "Failed to evaluate session authorization")
      return false
    }
  }

  static func splitByScope(_ claim: String?) throws -> (org: [String], user: [String]) {
    let data = try ClerkJSAuthorization.evaluate("splitByScope", arguments: [JSONEncoder().encode(claim)])
    let values = try JSONDecoder().decode([String: [String]].self, from: data)
    return (values["org"] ?? [], values["user"] ?? [])
  }
}

extension ClerkJSHostStore {
  static func biometricCredential(for kit: Clerk, appIdentifier: String? = nil) -> ClerkJSNativeCapability {
    let credentials = BiometricCredentials(
      keyManager: kit.dependencies.biometricCredentialKeyManager,
      credentialStore: kit.dependencies.biometricCredentialStore,
      appIdentifierProvider: { appIdentifier ?? Bundle.main.bundleIdentifier }
    )
    let capability = credentials.deviceCapability(scope: kit.runtimeScope) {
      try (Clerk.engineClient as? ClerkJSHostEngine)?.validateIdentityGeneration()
      try (Clerk.engineClient as? ClerkExternalEngine)?.validate()
    }
    return { request in
      do {
        return try await capability(request)
      } catch let error as BiometricCredentialKeyManagerError {
        throw try ClerkJSNativeCapabilityError(
          code: "native_biometric_key_error",
          message: error.localizedDescription,
          nativeError: JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(error))
        )
      }
    }
  }
}

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
      struct Request: Decodable { let operation: String; let key: String; let value: String?; let expected: String? }
      let request = try JSONDecoder().decode(Request.self, from: payload)
      switch request.operation {
      case "read": return try await JSONEncoder().encode(storage.read(request.key))
      case "write": try await storage.write(request.key, request.value); return Data("null".utf8)
      case "compareAndSwap": return try await JSONEncoder().encode(storage.compareAndSwap(request.key, request.expected, request.value))
      default: throw ClerkClientError(message: "Unsupported native storage operation.")
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
