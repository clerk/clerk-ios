#if !os(watchOS)
import Foundation
@preconcurrency import JavaScriptCore

final class JSRuntime: @unchecked Sendable {
  let queue = DispatchQueue(label: "com.clerk.jscore")
  private(set) var context: JSContext!
  let host: NativeHost
  private var bundleEvaluated = false
  private var nextCallID: UInt64 = 1
  private var currentCall: Call?

  init(tokenCache: ClerkJSTokenCache) {
    host = NativeHost(tokenCache: tokenCache)
    queue.sync {
      let context = JSContext()!
      self.context = context
      self.host.runtime = self
      self.host.install(on: context)
    }
  }

  deinit {
    queue.sync {
      host.invalidate()
    }
  }

  var currentCallID: UInt64? {
    currentCall?.id
  }

  var lastClientJSON: Data? {
    queue.sync { host.lastClientJSON }
  }

  var lastEnvironmentJSON: Data? {
    queue.sync { host.lastEnvironmentJSON }
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
          self.currentCall = call
          if box.cancelRequested {
            self.host.abortFetches(for: call.id)
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
        runtime.host.abortFetches(for: call.id)
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
    if currentCall?.id == call.id {
      currentCall = nil
    }
    call.publish(result)
  }

  private func ensureBundleEvaluated() throws {
    if bundleEvaluated {
      return
    }
    guard let url = Bundle.module.url(forResource: "clerk.native", withExtension: "js") else {
      throw ClerkJSCoreError.missingBundle
    }
    let source = try String(contentsOf: url, encoding: .utf8)
    context.exception = nil
    context.evaluateScript(source, withSourceURL: url)
    if let exception = context.exception {
      throw ClerkJSCoreError.javascript(exception.toString() ?? "Bundle evaluate failed")
    }
    let clerkType = context.evaluateScript("typeof Clerk")?.toString() ?? "undefined"
    if clerkType != "function" {
      let moduleType = context.evaluateScript("typeof module")?.toString() ?? "undefined"
      let exportsType = context.evaluateScript("typeof exports")?.toString() ?? "undefined"
      throw ClerkJSCoreError.javascript(
        "globalThis.Clerk missing after evaluate (typeof Clerk=\(clerkType), typeof module=\(moduleType), typeof exports=\(exportsType))"
      )
    }
    guard let invokeURL = Bundle.module.url(forResource: "native-invoke", withExtension: "js") else {
      throw ClerkJSCoreError.missingBundle
    }
    let invokeSource = try String(contentsOf: invokeURL, encoding: .utf8)
    context.exception = nil
    context.evaluateScript(invokeSource, withSourceURL: invokeURL)
    if let exception = context.exception {
      throw ClerkJSCoreError.javascript(exception.toString() ?? "native-invoke evaluate failed")
    }
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
