import Foundation
import Observation

public enum CoreFailureKind: String, Sendable { case clerk, rejection, bridge, cancelled }

public struct CoreError: Error, Sendable {
  public let kind: CoreFailureKind
  public let code: String
  public let message: String
  public let details: JSONValue?
  public init(code: String, message: String = "The operation could not be completed.", details: JSONValue? = nil, kind: CoreFailureKind = .bridge) {
    self.kind = kind; self.code = code; self.message = message; self.details = details
  }

  public static let invalidValue = CoreError(code: "invalid_value")
  public static let invalidResource = CoreError(code: "invalid_resource")
  static func decode(_ value: JSONValue) throws -> CoreError {
    let v = try value.object()
    return try .init(code: (v["code"] ?? .undefined).string(), message: (v["message"] ?? .string("The operation could not be completed.")).string(), details: v["errors"], kind: CoreFailureKind(rawValue: (v["kind"] ?? .string("bridge")).string()) ?? .bridge)
  }
}

public struct ResourceHandle: Hashable, Sendable {
  public let id: String
  public let generation: Int
  public let type: String
  public var json: JSONValue {
    .object(["id": .string(id), "generation": .number(Double(generation)), "type": .string(type)])
  }

  public static func decode(_ value: JSONValue) throws -> ResourceHandle {
    let v = try value.object()
    let generation = try (v["generation"] ?? .undefined).number()
    guard generation >= 0, generation < Double(Int.max), generation.rounded() == generation else { throw CoreError.invalidResource }
    return try .init(id: (v["id"] ?? .undefined).string(), generation: Int(generation), type: (v["type"] ?? .undefined).string())
  }

  public static func decodeReference(_ value: JSONValue) throws -> ResourceHandle {
    try decode(value.object()["$ref"] ?? .undefined)
  }
}

@MainActor public protocol CoreResource: AnyObject {
  var handle: ResourceHandle { get }
  var context: ResourceContext { get }
  var isInvalidated: Bool { get }
  func prepare(_ value: JSONValue) throws -> any Sendable
}

/// A transport has one Clerk owner. Embedded and Expo transports share this protocol.
@MainActor public protocol CoreTransport: AnyObject {
  var receive: (@MainActor (JSONValue) -> Void)? { get set }
  func send(_ message: JSONValue) throws
  func close()
}

@MainActor public final class ResourceContext {
  private weak var owner: CoreRuntime?
  private let ownedRuntime: CoreRuntime?
  private var cachedState: (any Sendable)?
  let leaseID = UUID()
  private let handle: ResourceHandle
  init(runtime: CoreRuntime, handle: ResourceHandle, ownsRuntime: Bool) {
    owner = runtime; self.handle = handle; ownedRuntime = ownsRuntime ? runtime : nil
  }

  public func requireRuntime() throws -> CoreRuntime {
    guard let owner = ownedRuntime ?? owner else { throw CoreError(code: "runtime_unavailable") }; return owner
  }

  public func isInvalidated(_ handle: ResourceHandle) -> Bool {
    owner?.isInvalidated(handle) ?? true
  }

  public func state<T>(_ handle: ResourceHandle, as _: T.Type) -> T {
    if let state: T = owner?.stateIfPresent(handle, as: T.self) { return state }
    guard let state = cachedState as? T else { preconditionFailure("Resource state is unavailable") }; return state
  }

  func store(_ state: any Sendable) {
    cachedState = state
  }

  isolated deinit {
    let leaseID = leaseID
    let handle = handle
    Task { @MainActor [weak owner] in owner?.release(handle, leaseID: leaseID) }
  }
}

@MainActor @Observable public final class CoreRuntime {
  @MainActor private final class WeakResource {
    weak var value: (any CoreResource)?
    let leaseID: UUID
    init(_ value: any CoreResource) {
      self.value = value; leaseID = value.context.leaseID
    }
  }

  public private(set) var revision: Int = -1
  public private(set) var epoch: Int = 0
  public private(set) var roots: [String: ResourceHandle] = [:]
  public private(set) var isAvailable = true
  @ObservationIgnored private let transport: any CoreTransport
  @ObservationIgnored private var resources: [ResourceHandle: WeakResource] = [:]
  @ObservationIgnored private var states: [ResourceHandle: JSONValue] = [:]
  @ObservationIgnored private var typedStates: [ResourceHandle: any Sendable] = [:]
  @ObservationIgnored private var projectedHandles: Set<ResourceHandle> = []
  @ObservationIgnored private var pending: [String: CheckedContinuation<JSONValue, any Error>] = [:]
  @ObservationIgnored private var pendingOwners: [String: any CoreResource] = [:]
  @ObservationIgnored private var applying = false
  @ObservationIgnored private var staged: [ResourceHandle: any CoreResource] = [:]
  public init(transport: any CoreTransport) {
    self.transport = transport
    transport.receive = { [weak self] message in self?.receive(message) }
  }

  public func resource<T: CoreResource>(_ handle: ResourceHandle, as _: T.Type) throws -> T {
    guard isAvailable, applying ? projectedHandles.contains(handle) : typedStates[handle] != nil else { throw CoreError(code: "stale_resource") }
    if let resource = staged[handle] ?? resources[handle]?.value {
      guard let typed = resource as? T else { throw CoreError.invalidResource }; return typed
    }
    let resource = try GeneratedBindings.makeResource(handle, runtime: self)
    guard let typed = resource as? T else { throw CoreError.invalidResource }
    resources[handle] = WeakResource(resource)
    if applying { staged[handle] = resource }
    else {
      guard let state = typedStates[handle] else { resources.removeValue(forKey: handle); throw CoreError.invalidResource }
      resource.context.store(state)
    }
    return typed
  }

  public func isInvalidated(_ handle: ResourceHandle) -> Bool {
    _ = revision; return !isAvailable || typedStates[handle] == nil
  }

  func stateIfPresent<T>(_ handle: ResourceHandle, as _: T.Type) -> T? {
    _ = revision; return typedStates[handle] as? T
  }

  public func root<T: CoreResource>(_ name: String, as _: T.Type) throws -> T? {
    guard let handle = roots[name] else { return nil }; return try resource(handle, as: T.self)
  }

  public func initialize(publishableKey: String, callbackURL: URL, platform: String, capabilities: [String]) async throws {
    let id = UUID().uuidString
    _ = try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONValue, any Error>) in
        pending[id] = continuation
        do {
          try transport.send(.object(["kind": .string("init"), "id": .string(id), "configuration": .object([
            "publishableKey": .string(publishableKey), "callbackUrl": .string(callbackURL.absoluteString), "platform": .string(platform),
            "protocolVersion": .number(Double(GeneratedBindings.protocolVersion)), "contractHash": .string(GeneratedBindings.contractHash),
            "capabilities": .array(capabilities.map(JSONValue.string)),
          ])]))
        } catch { pending.removeValue(forKey: id)?.resume(throwing: error) }
      }
    } onCancel: { Task { @MainActor [weak self] in self?.close() } }
  }

  public func invoke(owner: any CoreResource, target: ResourceHandle, operation: String, arguments: [JSONValue]) async throws -> JSONValue {
    guard isAvailable, states[target] != nil else { throw CoreError(code: "stale_resource") }
    let id = UUID().uuidString
    pendingOwners[id] = owner
    defer { pendingOwners.removeValue(forKey: id) }
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        pending[id] = continuation
        do { try transport.send(.object(["kind": .string("invoke"), "id": .string(id), "target": target.json, "operation": .string(operation), "args": .array(arguments)])) }
        catch { pending.removeValue(forKey: id)?.resume(throwing: error) }
      }
    } onCancel: {
      Task { @MainActor [weak self] in
        guard let self, let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CancellationError())
        try? transport.send(.object(["kind": .string("cancel"), "id": .string(id)]))
      }
    }
  }

  public func checkErrorResult(_ value: JSONValue) throws {
    let result = try value.object()
    guard let error = result["error"] else { throw CoreError.invalidValue }
    if error != .null { throw try CoreError.decode(error) }
  }

  public func receive(_ message: JSONValue) {
    do {
      let m = try message.object()
      let kind = try (m["kind"] ?? .undefined).string()
      if let state = m["state"] { try apply(state) }
      if kind == "ready" {
        let manifest = try (m["manifest"] ?? .undefined).object()
        guard manifest["contractHash"] == .string(GeneratedBindings.contractHash), manifest["protocolVersion"] == .number(Double(GeneratedBindings.protocolVersion)) else { throw CoreError(code: "incompatible_bindings") }
        let id = try (m["id"] ?? .undefined).string()
        pending.removeValue(forKey: id)?.resume(returning: .null)
      } else if kind == "complete" {
        let id = try (m["id"] ?? .undefined).string()
        if let failure = m["failure"] { try pending.removeValue(forKey: id)?.resume(throwing: CoreError.decode(failure)) }
        else { pending.removeValue(forKey: id)?.resume(returning: m["result"] ?? .undefined) }
      } else if kind == "runtimeError" || kind == "unavailable" || kind == "initializationFailed" { throw try m["failure"].map(CoreError.decode) ?? CoreError(code: "runtime_unavailable") }
    } catch { fail(error) }
  }

  private func apply(_ value: JSONValue) throws {
    let v = try value.object()
    let nextRevision = try Int((v["revision"] ?? .undefined).number())
    if nextRevision <= revision { return }
    let nextEpoch = try Int((v["epoch"] ?? .undefined).number())
    guard nextEpoch >= epoch else { throw CoreError(code: "stale_state") }
    var nextStates = states
    let invalid = try (v["invalidated"] ?? .array([])).array().map(ResourceHandle.decode)
    for handle in invalid {
      nextStates.removeValue(forKey: handle)
    }
    let projections = try (v["resources"] ?? .undefined).array()
    applying = true
    defer { applying = false; projectedHandles.removeAll(); staged.removeAll() }
    for projection in projections {
      let p = try projection.object()
      let handle = try ResourceHandle.decode(p["handle"] ?? .undefined)
      nextStates[handle] = p["state"] ?? .undefined
      if let existing = resources[handle]?.value { staged[handle] = existing }
      else { staged[handle] = try GeneratedBindings.makeResource(handle, runtime: self) }
    }
    projectedHandles = Set(nextStates.keys)
    var nextTypedStates = typedStates
    for handle in invalid {
      nextTypedStates.removeValue(forKey: handle)
    }
    for (handle, resource) in staged {
      guard let state = nextStates[handle] else { throw CoreError.invalidResource }
      nextTypedStates[handle] = try resource.prepare(state)
    }
    let rootValues = try (v["roots"] ?? .undefined).object()
    var nextRoots: [String: ResourceHandle] = [:]
    for (name, value) in rootValues where value != .null {
      nextRoots[name] = try ResourceHandle.decode(value)
    }
    // All decoding succeeds before any observable property changes.
    for handle in invalid {
      resources.removeValue(forKey: handle)
    }
    states = nextStates
    for (handle, resource) in staged {
      resources[handle] = WeakResource(resource)
    }
    typedStates = nextTypedStates
    for (handle, resource) in staged {
      if let state = nextTypedStates[handle] { resource.context.store(state) }
    }
    roots = nextRoots
    epoch = nextEpoch
    revision = nextRevision
  }

  fileprivate func release(_ handle: ResourceHandle, leaseID: UUID) {
    guard isAvailable, !roots.values.contains(handle), resources[handle]?.leaseID == leaseID, resources[handle]?.value == nil else { return }
    resources.removeValue(forKey: handle)
    states.removeValue(forKey: handle)
    typedStates.removeValue(forKey: handle)
    try? transport.send(.object(["kind": .string("release"), "target": handle.json]))
  }

  private func fail(_ error: any Error) {
    isAvailable = false
    let continuations = pending.values
    pending.removeAll()
    pendingOwners.removeAll()
    for continuation in continuations {
      continuation.resume(throwing: error)
    }
    revision += 1
  }

  isolated deinit { transport.close() }
  public func close() {
    try? transport.send(.object(["kind": .string("dispose")]))
    transport.close()
    fail(CoreError(code: "runtime_disposed"))
    states.removeAll(); typedStates.removeAll(); resources.removeAll(); roots.removeAll()
  }
}
