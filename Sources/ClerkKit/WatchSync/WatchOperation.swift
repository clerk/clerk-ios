import ClerkSnapshots
import Foundation

struct WatchOperationRequest: Codable {
  let id: UUID
  let publishableKey: String
  let clientId: String?
  let sessionId: String?
  let invocation: JSONValue
}

struct WatchOperationResponse: Codable {
  let id: UUID
  let result: JSONValue?
  let apiError: ClerkAPIError?
  let message: String?
  let state: Data?
}

@MainActor
final class WatchOperationEngine: ClerkEngineClient {
  private let scope: ClerkRuntimeScope
  private let coordinator: WatchConnectivityCoordinator?
  private var disposed = false
  private var requests: [UUID: Task<Data, Error>] = [:]

  init(kit: Clerk) {
    scope = kit.runtimeScope
    coordinator = kit.watchConnectivityCoordinator
  }

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    guard !disposed else { throw CancellationError() }
    let clerk = try scope.requireCurrentClerk()
    if invocation.receiver == .clerk, invocation.method == "initialize" { return .null }
    if invocation.receiver == .clerk, invocation.method == "setApplicationActive", invocation.arguments.first != .bool(true) { return .null }
    guard let coordinator else {
      throw ClerkClientError(message: "Enable watchConnectivityEnabled on both apps to use Clerk operations on Apple Watch.")
    }
    let call = invocation.receiver == .clerk && invocation.method == "setApplicationActive"
      ? ClerkJSInvocation(receiver: .clerk, method: "refreshClient", arguments: [])
      : invocation
    let request = try WatchOperationRequest(
      id: UUID(), publishableKey: clerk.publishableKey,
      clientId: clerk.client?.id, sessionId: clerk.session?.id,
      invocation: JSONValue(encoding: call)
    )
    let generation = clerk.clientResponseGeneration
    let encoded = try JSONEncoder().encode(request)
    let transmission = Task { try await coordinator.requestOperation(encoded) }
    requests[request.id] = transmission
    defer { requests.removeValue(forKey: request.id) }
    let data = try await withTaskCancellationHandler {
      try await transmission.value
    } onCancel: {
      transmission.cancel()
    }
    guard !disposed, try scope.requireCurrentClerk().clientResponseGeneration == generation else { throw CancellationError() }
    let response = try JSONDecoder().decode(WatchOperationResponse.self, from: data)
    guard response.id == request.id else { throw ClerkClientError(message: "The paired iPhone returned an unrelated Clerk response.") }
    if let state = response.state {
      try await coordinator.applyOperationState(state, to: clerk)
    }
    try scope.validateStableRuntime()
    if let error = response.apiError { throw error }
    if let message = response.message { throw ClerkClientError(message: String.LocalizationValue(stringLiteral: message)) }
    return response.result ?? .null
  }

  func invalidate() {
    disposed = true
    requests.values.forEach { $0.cancel() }
    requests.removeAll()
  }

  func dispose() async {
    invalidate()
  }
}

extension WatchConnectivityCoordinator {
  func handleOperation(_ data: Data, for clerk: Clerk) async throws -> Data {
    let request = try JSONDecoder().decode(WatchOperationRequest.self, from: data)
    guard request.publishableKey == clerk.publishableKey else {
      throw ClerkClientError(message: "The paired apps use different Clerk instances.")
    }
    let scope = clerk.runtimeScope
    var result: JSONValue?
    var apiError: ClerkAPIError?
    var message: String?
    do {
      let engine = try await Clerk.requireEngineClient()
      try scope.validateStableRuntime()
      result = try await engine.invoke(.init(receiver: .clerk, method: "invokeForIdentity", arguments: [
        request.invocation,
        .object([
          "clientId": request.clientId.map(JSONValue.string) ?? .null,
          "sessionId": request.sessionId.map(JSONValue.string) ?? .null,
        ]),
      ]))
    } catch let error as ClerkAPIError {
      apiError = error
    } catch {
      message = error.localizedDescription
    }
    try scope.validateStableRuntime()
    let state = try operationState(from: clerk)
    return try JSONEncoder().encode(WatchOperationResponse(id: request.id, result: result, apiError: apiError, message: message, state: state))
  }
}
