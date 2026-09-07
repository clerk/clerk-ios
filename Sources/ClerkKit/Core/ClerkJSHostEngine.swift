import ClerkJSCore
import ClerkSnapshots
import Foundation

@MainActor
final class ClerkJSHostEngine: ClerkEngineClient {
  private let host: ClerkJSHost
  private let scope: ClerkRuntimeScope
  private var disposed = false
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

  static func makeHost(for kit: Clerk) -> ClerkJSHost {
    // Persistence belongs to ClerkKit's complete identity transaction. The host's
    // cache callbacks only seed this realm; published states are its sole writer.
    let token = kit.identityController.currentDeviceToken ?? ""
    let resources = ClerkJSCachedResources(
      client: kit.client.flatMap { try? JSONEncoder.clerkEncoder.encode($0) },
      environment: kit.environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    )
    return ClerkJSHost(
      publishableKey: kit.publishableKey,
      tokenCache: .init(getToken: { token }, saveToken: { _ in }),
      resourceCache: .init(load: { resources }, save: { _ in }),
      oauthRedirectURL: URL(string: kit.options.redirectConfig.redirectUrl) ?? ClerkJSRuntime.defaultOAuthRedirectURL,
      proxyURL: kit.options.proxyUrl
    )
  }
}

enum KitJSErrorMapping {
  static func kitError(_ error: ClerkJSError) -> any Error {
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
    return
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
