#if canImport(JavaScriptCore)
import CryptoKit
import Foundation
import JavaScriptCore
import Security

/// Every JavaScriptCore access, including teardown, runs on one private queue.
private final class JavaScriptWorker: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.clerk.core.javascript")
  private var context: JSContext?
  private var entry: JSValue?
  private var closed = false
  private let emit: @Sendable (JSONValue) -> Void
  init(emit: @escaping @Sendable (JSONValue) -> Void) {
    self.emit = emit
  }

  func start(source: String, completion: @escaping @Sendable (CoreError?) -> Void) {
    queue.async { [self] in
      guard !closed, context == nil, let context = JSContext() else { completion(CoreError(code: "engine_unavailable")); return }
      self.context = context
      context.exceptionHandler = { [weak self] _, _ in self?.emit(.object(["kind": .string("runtimeError")])) }
      let output: @convention(block) (String) -> Void = { [weak self] encoded in
        guard let data = encoded.data(using: .utf8), data.count <= 16 * 1024 * 1024,
              let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else {
          self?.emit(.object(["kind": .string("runtimeError")])); return
        }
        self?.emit(value)
      }
      let random: @convention(block) (Int) -> String? = { count in
        guard count >= 0, count <= 65536 else { return nil }
        if count == 0 { return "" }
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return result == errSecSuccess ? data.base64EncodedString() : nil
      }
      context.setObject(output, forKeyedSubscript: "__clerkNativeEmit" as NSString)
      context.setObject(random, forKeyedSubscript: "__clerkNativeRandom" as NSString)
      context.evaluateScript(source, withSourceURL: URL(string: "clerk-bundled-core.js"))
      guard context.exception == nil, let entry = context.objectForKeyedSubscript("ClerkCore")?.objectForKeyedSubscript("receive"), !entry.isUndefined else {
        completion(CoreError(code: "invalid_core_bundle")); return
      }
      self.entry = entry
      completion(nil)
    }
  }

  func send(_ encoded: String) {
    queue.async { [self] in
      guard !closed, let entry else { return }
      // Arguments enter as data; only the packaged bundle is evaluated as source.
      entry.call(withArguments: [encoded])
    }
  }

  func close() {
    queue.async { [self] in
      closed = true
      entry = nil
      context?.exceptionHandler = nil
      context = nil
    }
  }
}

@MainActor public final class JavaScriptCoreTransport: CoreTransport {
  public var receive: (@MainActor (JSONValue) -> Void)?
  private var worker: JavaScriptWorker?
  private let capabilities: any NativeCapabilities
  private var jobs: [String: Task<Void, Never>] = [:]
  private var closed = false
  public init(capabilities: any NativeCapabilities) {
    self.capabilities = capabilities
  }

  public func start(bundle: Data, sha256: String) async throws {
    guard worker == nil, !closed else { throw CoreError(code: "runtime_already_initialized") }
    let actual = SHA256.hash(data: bundle).map { String(format: "%02x", $0) }.joined()
    guard actual == sha256, let source = String(data: bundle, encoding: .utf8) else { throw CoreError(code: "bundle_hash_mismatch") }
    let worker = JavaScriptWorker { [weak self] value in Task { @MainActor in self?.route(value) } }
    self.worker = worker
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      worker.start(source: source) { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }

  public func send(_ message: JSONValue) throws {
    guard !closed, let worker else { throw CoreError(code: "runtime_unavailable") }
    let data = try JSONEncoder().encode(message)
    guard data.count <= 16 * 1024 * 1024, let encoded = String(data: data, encoding: .utf8) else { throw CoreError.invalidValue }
    worker.send(encoded)
  }

  private func route(_ value: JSONValue) {
    guard !closed, let message = try? value.object(), let kind = try? message["kind"]?.string() else { return }
    if kind == "hostRequest" {
      guard let id = try? message["id"]?.string(), let capability = try? message["capability"]?.string(), jobs[id] == nil else { return }
      jobs[id] = Task { [weak self] in
        guard let self else { return }
        var reply: [String: JSONValue] = ["kind": .string("hostReply"), "id": .string(id)]
        do { reply["result"] = try await capabilities.perform(capability, arguments: message["args"] ?? .null) }
        catch { reply["error"] = .object(["code": .string((error as? CoreError)?.code ?? (error is CancellationError ? "user_cancelled" : "host_failure"))]) }
        jobs.removeValue(forKey: id)
        if !Task.isCancelled { try? send(.object(reply)) }
      }
    } else if kind == "hostCancel", let id = try? message["id"]?.string() { jobs.removeValue(forKey: id)?.cancel() }
    else { receive?(value) }
  }

  public func close() {
    closed = true
    for job in jobs.values {
      job.cancel()
    }
    jobs.removeAll()
    worker?.close(); worker = nil
  }
}

#endif
