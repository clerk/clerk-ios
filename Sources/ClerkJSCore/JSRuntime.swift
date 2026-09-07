#if !os(watchOS)
import Foundation
@preconcurrency import JavaScriptCore

final class JSRuntime: @unchecked Sendable {
  let queue = DispatchQueue(label: "com.clerk.jscore")
  private(set) var context: JSContext!
  let host: NativeHost
  private var bundleEvaluated = false
  private var nextCallID: UInt64 = 1
  private var calls: [UInt64: Call] = [:]
  private var disposed = false
  private let queueKey = DispatchSpecificKey<Bool>()

  init(tokenCache: ClerkJSTokenCache, sessionConfiguration: URLSessionConfiguration? = nil) {
    host = NativeHost(tokenCache: tokenCache, sessionConfiguration: sessionConfiguration)
    queue.setSpecific(key: queueKey, value: true)
    queue.sync {
      let context = JSContext()!
      self.context = context
      self.host.runtime = self
      self.host.install(on: context)
    }
  }

  deinit {
    if DispatchQueue.getSpecific(key: queueKey) == true {
      host.invalidate()
    } else {
      queue.sync { host.invalidate() }
    }
  }

  var lastStateJSON: Data? {
    queue.sync { host.lastStateJSON }
  }

  func observeState(_ handler: (@Sendable (Data) -> Void)?) {
    queue.sync { host.onStateChange = handler }
  }

  func dispose() async {
    await withCheckedContinuation { continuation in
      queue.async {
        self.disposed = true
        self.host.onStateChange = nil
        _ = self.context.objectForKeyedSubscript("__clerkEmbeddedCore")?.invokeMethod("dispose", withArguments: [])
        self.host.invalidate()
        for call in self.calls.values {
          call.publish(.failure(ClerkJSCoreError.disposed))
        }
        self.calls.removeAll()
        continuation.resume()
      }
    }
  }

  func invokeJSON(receiver: String, method: String, argumentsJSON: String = "[]") async throws -> String {
    try await perform { [self] call in
      try ensureBundleEvaluated()
      let arguments = try JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8)) as? [Any] ?? []
      context.exception = nil
      guard let target = context.objectForKeyedSubscript(receiver),
            let value = target.invokeMethod(method, withArguments: arguments)
      else { throw jsError() }
      if context.exception != nil { throw jsError() }
      guard let encoded = context.objectForKeyedSubscript("__clerkEncodeResult")?.call(withArguments: [value]) else {
        throw jsError()
      }
      if encoded.isObject, encoded.hasProperty("then") {
        awaitPromise(encoded, call: call)
      } else {
        finish(call, .success(encoded.toString() ?? "null"))
      }
    }
  }

  var lastClientJSON: Data? {
    queue.sync { host.lastClientJSON }
  }

  var lastEnvironmentJSON: Data? {
    queue.sync { host.lastEnvironmentJSON }
  }

  var lastClientToken: String? {
    queue.sync { host.lastClientToken }
  }

  func hydrateClientToken() async {
    await host.hydrateClientToken()
  }

  func evaluateJSON(_ js: String) async throws -> String {
    try await perform { [self] call in
      try ensureBundleEvaluated()
      let wrapped = """
        (function(){
          var __v = (function(){ return (\(js)); })();
          if (__v && typeof __v.then === 'function') {
            return __v.then(function(r) {
              return JSON.stringify(r === undefined ? null : r);
            });
          }
          return JSON.stringify(__v === undefined ? null : __v);
        })()
        """
      context.exception = nil
      guard let value = context.evaluateScript(wrapped) else {
        throw jsError()
      }
      if let exception = context.exception {
        throw ClerkJSCoreError.javascript(exception.toString() ?? "JavaScript exception")
      }
      if value.isObject, value.hasProperty("then") {
        awaitPromise(value, call: call)
      } else {
        finish(call, .success(value.toString() ?? "null"))
      }
    }
  }

  private func perform(_ work: @escaping @Sendable (Call) throws -> Void) async throws -> String {
    let box = CallBox()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        queue.async {
          let call = Call(id: self.nextCallID, continuation: continuation)
          self.nextCallID += 1
          box.call = call
          guard !self.disposed else {
            call.publish(.failure(ClerkJSCoreError.disposed))
            return
          }
          self.calls[call.id] = call
          self.queue.asyncAfter(deadline: .now() + 120) { [weak self, weak call] in
            guard let self, let call, calls[call.id] != nil else { return }
            finish(call, .failure(ClerkJSCoreError.timedOut))
          }
          if box.cancelRequested {
            self.finish(call, .failure(ClerkJSCoreError.cancelled))
            return
          }
          do {
            try work(call)
          } catch {
            self.finish(call, .failure(error))
          }
        }
      }
    } onCancel: { [weak self] in
      guard let runtime = self else { return }
      runtime.queue.async {
        box.cancelRequested = true
        guard let call = box.call else { return }
        runtime.finish(call, .failure(ClerkJSCoreError.cancelled))
      }
    }
  }

  private func awaitPromise(_ value: JSValue, call: Call) {
    let onFulfilled: @convention(block) (JSValue?) -> Void = { [weak self] result in
      let text = result?.toString() ?? "null"
      guard let runtime = self else { return }
      runtime.queue.async {
        runtime.finish(call, .success(text))
      }
    }
    let onRejected: @convention(block) (JSValue?) -> Void = { [weak self] error in
      let message = error?.toString() ?? "Promise rejected"
      guard let runtime = self else { return }
      runtime.queue.async {
        runtime.finish(call, .failure(ClerkJSCoreError.javascript(message)))
      }
    }
    value.invokeMethod("then", withArguments: [onFulfilled, onRejected])
  }

  private func finish(_ call: Call, _ result: Result<String, Error>) {
    calls[call.id] = nil
    call.publish(result)
  }

  private func ensureBundleEvaluated() throws {
    if bundleEvaluated {
      return
    }
    guard let url = Bundle.module.url(forResource: "clerk.embedded", withExtension: "js") else {
      throw ClerkJSCoreError.missingBundle
    }
    let source = try String(contentsOf: url, encoding: .utf8)
    context.exception = nil
    context.evaluateScript(source, withSourceURL: url)
    if let exception = context.exception {
      throw ClerkJSCoreError.javascript(exception.toString() ?? "Bundle evaluate failed")
    }
    context.evaluateScript("""
      globalThis.Clerk = ClerkEmbedded.Clerk;
      globalThis.__clerkEncodeResult = function(value) {
        if (value && typeof value.then === 'function') {
          return value.then(function(result) { return JSON.stringify(result === undefined ? null : result); });
        }
        return JSON.stringify(value === undefined ? null : value);
      };
      """)
    if context.exception != nil { throw jsError() }
    bundleEvaluated = true
  }

  private func jsError() -> ClerkJSCoreError {
    ClerkJSCoreError.javascript(context.exception?.toString() ?? "JavaScript evaluation failed")
  }
}

final class Call: @unchecked Sendable {
  let id: UInt64
  private var continuation: CheckedContinuation<String, Error>?
  private var isPublished = false

  init(id: UInt64, continuation: CheckedContinuation<String, Error>) {
    self.id = id
    self.continuation = continuation
  }

  func publish(_ result: Result<String, Error>) {
    guard !isPublished else { return }
    isPublished = true
    continuation?.resume(with: result)
    continuation = nil
  }
}

final class CallBox: @unchecked Sendable {
  var call: Call?
  var cancelRequested = false
}
#endif
