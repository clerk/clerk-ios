#if !os(watchOS)
import ClerkSnapshots
import CryptoKit
import Foundation
@preconcurrency import JavaScriptCore
import Security

final class NativeHost: @unchecked Sendable {
  weak var runtime: JSRuntime?
  private let tokenCache: ClerkJSTokenCache
  var httpMiddleware = ClerkJSHTTPMiddleware()
  var resourceCache: ClerkJSResourceCache?
  var biometricCredential: ClerkJSNativeCapability?
  var secureStorage = ClerkJSSecureStorage.memory()
  let capabilities = ClerkJSPlatformCapabilities()
  let oauth = ClerkJSOAuthSession()
  private let session: URLSession
  private var nextTimerID: UInt64 = 1
  private var nextFetchID: UInt64 = 1
  private var nextCallbackID: UInt64 = 1
  private var timers: [UInt64: DispatchWorkItem] = [:]
  private var fetches: [UInt64: InFlightFetch] = [:]
  private var callbacks: [UInt64: JSValue] = [:]
  private(set) var lastStateJSON: Data?
  var onStateChange: (@Sendable (Data) -> Void)?
  var commitState: (@Sendable (Data) async throws -> Void)?
  private(set) var lastClientJSON: Data?
  private(set) var lastEnvironmentJSON: Data?
  private(set) var lastClientToken: String?

  init(tokenCache: ClerkJSTokenCache, sessionConfiguration: URLSessionConfiguration? = nil) {
    self.tokenCache = tokenCache
    let configuration = (sessionConfiguration?.copy() as? URLSessionConfiguration) ?? .ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.httpCookieAcceptPolicy = .never
    configuration.urlCache = nil
    session = URLSession(configuration: configuration)
  }

  func install(on context: JSContext) {
    installBridges(on: context)
    context.evaluateScript(Self.polyfillSource)
  }

  func hydrateClientToken() async {
    let token = await tokenCache.getToken()
    if !token.isEmpty {
      lastClientToken = token
    }
  }

  func invalidate() {
    timers.values.forEach { $0.cancel() }
    timers.removeAll()
    callbacks.removeAll()
    for id in Array(fetches.keys) {
      abortFetch(id)
    }
    if let biometricCredential {
      Task { _ = try? await biometricCredential(.object(["operation": .string("dispose")])) }
    }
    capabilities.cancel()
    oauth.cancel()
    session.invalidateAndCancel()
  }

  private func retainCallback(_ callback: JSValue) -> UInt64 {
    let id = nextCallbackID
    nextCallbackID += 1
    callbacks[id] = callback
    return id
  }

  private func takeCallback(_ id: UInt64) -> JSValue? {
    callbacks.removeValue(forKey: id)
  }

  private func installBridges(on context: JSContext) {
    let publishState: @convention(block) (String) -> Void = { [weak self] json in
      guard let self, let data = json.data(using: .utf8),
            let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return }
      lastStateJSON = data
      lastClientJSON = Self.snapshotData(state["client"])
      lastEnvironmentJSON = Self.snapshotData(state["environment"])
      lastClientToken = state["clientToken"] as? String
      onStateChange?(data)
    }
    context.setObject(publishState, forKeyedSubscript: "__clerkNativePublishState" as NSString)

    let commitState: @convention(block) (String, JSValue) -> Void = { [weak self] json, callback in
      guard let self, let runtime, let data = json.data(using: .utf8) else { return }
      let callbackID = retainCallback(callback)
      Task {
        do {
          try await self.commitState?(data)
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [NSNull()]) }
        } catch {
          let message = error.localizedDescription
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [message]) }
        }
      }
    }
    context.setObject(commitState, forKeyedSubscript: "__clerkNativeCommitStateImpl" as NSString)

    let parseURL: @convention(block) (String, String?) -> [String: String]? = { href, base in
      Self.parseURL(href, base: base)
    }
    context.setObject(parseURL, forKeyedSubscript: "__clerkNativeParseURL" as NSString)

    let atob: @convention(block) (String) -> String = { encoded in
      Self.atob(encoded)
    }
    context.setObject(atob, forKeyedSubscript: "__clerkNativeAtob" as NSString)

    let btoa: @convention(block) (String) -> String = { raw in
      Self.btoa(raw)
    }
    context.setObject(btoa, forKeyedSubscript: "__clerkNativeBtoa" as NSString)

    let sha256: @convention(block) ([UInt8]) -> [UInt8] = { bytes in
      Array(SHA256.hash(data: Data(bytes)))
    }
    context.setObject(sha256, forKeyedSubscript: "__clerkNativeSHA256" as NSString)

    let random: @convention(block) (Int) -> [UInt8] = { count in
      Self.randomBytes(count)
    }
    context.setObject(random, forKeyedSubscript: "__clerkNativeRandom" as NSString)

    let setTimeout: @convention(block) (JSValue, Double) -> NSNumber = { [weak self] callback, delayMs in
      guard let self, let runtime else { return 0 }
      let id = nextTimerID
      nextTimerID += 1
      let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        timers[id] = nil
        callback.call(withArguments: [])
      }
      timers[id] = work
      runtime.queue.asyncAfter(deadline: .now() + max(0, delayMs / 1000), execute: work)
      return NSNumber(value: id)
    }
    context.setObject(setTimeout, forKeyedSubscript: "__clerkNativeSetTimeout" as NSString)

    let clearTimeout: @convention(block) (JSValue) -> Void = { [weak self] value in
      let id = UInt64(value.toUInt32())
      self?.timers.removeValue(forKey: id)?.cancel()
    }
    context.setObject(clearTimeout, forKeyedSubscript: "__clerkNativeClearTimeout" as NSString)

    let fetch: @convention(block) (String, JSValue) -> NSNumber = { [weak self] payload, callback in
      NSNumber(value: self?.startFetch(payload: payload, callback: callback) ?? 0)
    }
    context.setObject(fetch, forKeyedSubscript: "__clerkNativeFetch" as NSString)

    let abortFetch: @convention(block) (JSValue) -> Void = { [weak self] value in
      self?.abortFetch(UInt64(value.toUInt32()))
    }
    context.setObject(abortFetch, forKeyedSubscript: "__clerkNativeAbortFetch" as NSString)

    let getToken: @convention(block) (JSValue) -> Void = { [weak self] callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        let token = await self.tokenCache.getToken()
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull(), token])
        }
      }
    }
    context.setObject(getToken, forKeyedSubscript: "__clerkNativeGetTokenImpl" as NSString)

    let saveToken: @convention(block) (String, JSValue) -> Void = { [weak self] token, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        await self.tokenCache.saveToken(token)
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull()])
        }
      }
    }
    context.setObject(saveToken, forKeyedSubscript: "__clerkNativeSaveTokenImpl" as NSString)

    let getCachedResources: @convention(block) (JSValue) -> Void = { [weak self] callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        let cached = await self.resourceCache?.load() ?? ClerkJSCachedResources()
        let json = Self.encodedCachedResources(cached)
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull(), json])
        }
      }
    }
    context.setObject(getCachedResources, forKeyedSubscript: "__clerkNativeGetCachedResourcesImpl" as NSString)

    let saveCachedResources: @convention(block) (String, JSValue) -> Void = { [weak self] payload, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      let parsed = Self.parsedCachedResources(payload)
      Task {
        await self.resourceCache?.save(parsed)
        runtime.queue.async {
          self.takeCallback(callbackID)?.call(withArguments: [NSNull()])
        }
      }
    }
    context.setObject(saveCachedResources, forKeyedSubscript: "__clerkNativeSaveCachedResourcesImpl" as NSString)

    let storage: @convention(block) (String, JSValue) -> Void = { [weak self] payload, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      let storage = secureStorage
      Task {
        do {
          let json = try await String(decoding: storage.perform(Data(payload.utf8)), as: UTF8.self)
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [NSNull(), json]) }
        } catch {
          let message = error.localizedDescription
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [message, NSNull()]) }
        }
      }
    }
    context.setObject(storage, forKeyedSubscript: "__clerkNativeStorageImpl" as NSString)

    let biometricCredential: @convention(block) (String, JSValue) -> Void = { [weak self] payload, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      let capability = self.biometricCredential
      Task {
        do {
          guard let capability else { throw ClerkJSCoreError.invalidArgument("Biometric credential capability is unavailable") }
          let request = try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
          let result = try await capability(request)
          let json = try String(decoding: JSONEncoder().encode(result), as: UTF8.self)
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [NSNull(), json]) }
        } catch {
          let json: String
          if let native = error as? ClerkJSNativeCapabilityError, let data = try? JSONEncoder().encode(native) {
            json = String(decoding: data, as: UTF8.self)
          } else {
            let data = try? JSONEncoder().encode(["message": error.localizedDescription])
            json = data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
          }
          runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [json, NSNull()]) }
        }
      }
    }
    context.setObject(biometricCredential, forKeyedSubscript: "__clerkNativeBiometricCredentialImpl" as NSString)

    let openOAuth: @convention(block) (String, Bool, JSValue) -> Void = { [weak self] href, ephemeral, callback in
      guard let self, let runtime else { return }
      let callbackID = retainCallback(callback)
      Task {
        let result = await self.oauth.open(href: href, prefersEphemeralSession: ephemeral)
        runtime.queue.async {
          switch result {
          case .success(let callbackURL):
            self.takeCallback(callbackID)?.call(withArguments: [NSNull(), callbackURL])
          case .failure(let error):
            self.takeCallback(callbackID)?.call(withArguments: [error.json, NSNull()])
          }
        }
      }
    }
    context.setObject(openOAuth, forKeyedSubscript: "__clerkNativeOAuthOpenImpl" as NSString)

    let ceremonies = [
      ("createPublicCredentials", "__clerkNativeCreatePublicCredentialsImpl"),
      ("getPublicCredentials", "__clerkNativeGetPublicCredentialsImpl"),
      ("startAppleAuthentication", "__clerkNativeAppleSignInImpl"),
      ("biometricPresence", "__clerkNativeBiometricPresenceImpl"),
      ("promptBiometrics", "__clerkNativePromptBiometricsImpl"),
      ("prepareDeviceAttestation", "__clerkNativePrepareDeviceAttestationImpl"),
      ("prepareDeviceAssertion", "__clerkNativePrepareDeviceAssertionImpl"),
    ]
    for (action, name) in ceremonies {
      let perform: @convention(block) (String, JSValue) -> Void = { [weak self] payload, callback in
        guard let self, let runtime else { return }
        let callbackID = retainCallback(callback)
        Task {
          do {
            let json = try await self.capabilities.perform(action, payload: payload)
            runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [NSNull(), json]) }
          } catch {
            let json = String(decoding: ClerkJSPlatformCapabilities.errorJSON(error), as: UTF8.self)
            runtime.queue.async { self.takeCallback(callbackID)?.call(withArguments: [json, NSNull()]) }
          }
        }
      }
      context.setObject(perform, forKeyedSubscript: name as NSString)
    }
  }

  private func startFetch(payload: String, callback: JSValue) -> UInt64 {
    let id = nextFetchID
    nextFetchID += 1
    guard let data = payload.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let urlString = object["url"] as? String,
          let url = URL(string: urlString),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme)
    else {
      callback.call(withArguments: ["Invalid HTTP URL", NSNull()])
      return id
    }

    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.httpShouldHandleCookies = false
    request.httpMethod = (object["method"] as? String) ?? "GET"
    if let headers = object["headers"] as? [String: String] {
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }
    if let bodyBase64 = object["bodyBase64"] as? String {
      request.httpBody = Data(base64Encoded: bodyBase64)
    } else if let body = object["body"] as? String {
      request.httpBody = body.data(using: .utf8)
    }

    let originalRequest = request
    let middleware = httpMiddleware
    let task = Task { [weak self] in
      guard let self, let runtime else { return }
      do {
        let prepared = try await middleware.prepare(originalRequest)
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: prepared)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
          throw URLError(.badServerResponse)
        }
        try await middleware.validate(http, data, prepared)
        try Task.checkCancellation()
        runtime.queue.async { self.completeFetch(id, data: data, response: response, error: nil) }
      } catch {
        runtime.queue.async { self.completeFetch(id, data: nil, response: nil, error: error) }
      }
    }
    fetches[id] = InFlightFetch(task: task, callback: callback)
    return id
  }

  private func completeFetch(_ id: UInt64, data: Data?, response: URLResponse?, error: Error?) {
    guard let inflight = fetches.removeValue(forKey: id) else { return }
    if let error {
      if (error as? URLError)?.code == .cancelled {
        inflight.callback.call(withArguments: ["The operation was aborted.", NSNull()])
      } else {
        inflight.callback.call(withArguments: [error.localizedDescription, NSNull()])
      }
      return
    }
    guard let http = response as? HTTPURLResponse else {
      inflight.callback.call(withArguments: ["Expected an HTTP response", NSNull()])
      return
    }
    var headers: [String: String] = [:]
    for (key, value) in http.allHeaderFields {
      headers[String(describing: key).lowercased()] = String(describing: value)
    }
    if let authorization = http.value(forHTTPHeaderField: "Authorization"), !authorization.isEmpty {
      headers["authorization"] = authorization
    }
    let payload: [String: Any] = [
      "status": http.statusCode,
      "statusText": HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
      "headers": headers,
      "body": String(data: data ?? Data(), encoding: .utf8) ?? "",
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: json, encoding: .utf8)
    else {
      inflight.callback.call(withArguments: ["Failed to encode response", NSNull()])
      return
    }
    inflight.callback.call(withArguments: [NSNull(), text])
  }

  private func abortFetch(_ id: UInt64) {
    guard let inflight = fetches.removeValue(forKey: id) else { return }
    inflight.task.cancel()
    inflight.callback.call(withArguments: ["The operation was aborted.", NSNull()])
  }

  private static func parseURL(_ href: String, base: String?) -> [String: String]? {
    let url: URL
    if let base, let baseURL = URL(string: base), let resolved = URL(string: href, relativeTo: baseURL) {
      url = resolved.absoluteURL
    } else if let parsed = URL(string: href), parsed.scheme != nil {
      url = parsed
    } else {
      return nil
    }
    let hostname = url.host ?? ""
    let port = url.port.map(String.init) ?? ""
    let host = port.isEmpty ? hostname : "\(hostname):\(port)"
    let scheme = url.scheme.map { "\($0):" } ?? ""
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    var pathname = components?.percentEncodedPath ?? url.path
    if pathname.isEmpty, ["http", "https", "ftp", "ws", "wss"].contains(url.scheme?.lowercased() ?? "") {
      pathname = "/"
    }
    let search = url.query.map { "?\($0)" } ?? ""
    let hash = url.fragment.map { "#\($0)" } ?? ""
    return [
      "href": url.absoluteString,
      "protocol": scheme,
      "host": host,
      "hostname": hostname,
      "username": components?.percentEncodedUser ?? "",
      "password": components?.percentEncodedPassword ?? "",
      "port": port,
      "pathname": pathname,
      "search": search,
      "hash": hash,
      "origin": "\(scheme)//\(host)",
    ]
  }

  private static func atob(_ encoded: String) -> String {
    var base64 = encoded
    let pad = base64.count % 4
    if pad != 0 {
      base64.append(String(repeating: "=", count: 4 - pad))
    }
    guard let data = Data(base64Encoded: base64) else { return "" }
    return String(data: data, encoding: .isoLatin1) ?? ""
  }

  private static func btoa(_ raw: String) -> String {
    (raw.data(using: .isoLatin1) ?? Data(raw.utf8)).base64EncodedString()
  }

  private static func encodedCachedResources(_ resources: ClerkJSCachedResources) -> String {
    "{\"client\":\(jsonFragment(resources.client)),\"environment\":\(jsonFragment(resources.environment))}"
  }

  private static func parsedCachedResources(_ payload: String) -> ClerkJSCachedResources {
    guard let data = payload.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return ClerkJSCachedResources()
    }
    return ClerkJSCachedResources(
      client: snapshotData(object["client"]),
      environment: snapshotData(object["environment"])
    )
  }

  private static func jsonFragment(_ data: Data?) -> String {
    guard let data, (try? JSONSerialization.jsonObject(with: data)) != nil,
          let text = String(data: data, encoding: .utf8)
    else {
      return "null"
    }
    return text
  }

  private static func snapshotData(_ value: Any?) -> Data? {
    guard let value, !(value is NSNull) else {
      return nil
    }
    return try? JSONSerialization.data(withJSONObject: value)
  }

  private static func randomBytes(_ count: Int) -> [UInt8] {
    let size = max(0, count)
    var bytes = [UInt8](repeating: 0, count: size)
    if size > 0 {
      _ = SecRandomCopyBytes(kSecRandomDefault, size, &bytes)
    }
    return bytes
  }
}

private struct InFlightFetch {
  let task: Task<Void, Never>
  let callback: JSValue
}
#endif
