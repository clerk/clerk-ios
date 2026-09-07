import Foundation

public struct ClerkJSTokenCache: Sendable {
  public var getToken: @Sendable () async -> String
  public var saveToken: @Sendable (String) async -> Void

  public init(
    getToken: @escaping @Sendable () async -> String,
    saveToken: @escaping @Sendable (String) async -> Void
  ) {
    self.getToken = getToken
    self.saveToken = saveToken
  }

  public static func memory() -> ClerkJSTokenCache {
    let box = MemoryTokenBox()
    return ClerkJSTokenCache(
      getToken: { await box.get() },
      saveToken: { await box.save($0) }
    )
  }
}

private actor MemoryTokenBox {
  var token = ""

  func get() -> String {
    token
  }

  func save(_ token: String) {
    self.token = token
  }
}

public final class ClerkJSRuntime: @unchecked Sendable {
  public static let sdkVersion = "1.5.3"
  public let generation = UUID().uuidString

  public static var defaultOAuthRedirectURL: URL {
    let scheme = Bundle.main.bundleIdentifier ?? "clerk"
    return URL(string: "\(scheme)://sso-callback")!
  }

  #if os(watchOS)
  public init(
    sdkVersion _: String = ClerkJSRuntime.sdkVersion,
    tokenCache _: ClerkJSTokenCache = .memory(),
    resourceCache _: ClerkJSResourceCache? = nil,
    oauthRedirectURL _: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    proxyURL _: URL? = nil,
    appAttestKeyIdStore _: ClerkJSAppAttestKeyIdStore = .memory()
  ) {}

  public var lastStateJSON: Data? {
    nil
  }

  public func observeState(_: (@Sendable (Data) -> Void)?) {}
  public func dispose() async {}

  public var lastFAPIClientJSON: Data? {
    nil
  }

  public var lastFAPIEnvironmentJSON: Data? {
    nil
  }

  public var lastClientToken: String? {
    nil
  }

  public func load(publishableKey _: String) async throws {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func evaluateJSON(_: String) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func call(methodPath _: String, args _: some Encodable) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func callReturning(methodPath _: String, args _: some Encodable) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func callOnResourceReturning(
    factoryPath _: String,
    id _: String,
    method _: String,
    argsJSON _: String
  ) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func callOnResourceSteps(
    receiverPath _: String,
    receiverArgJSON _: String,
    stepsJSON _: String
  ) async throws -> String {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func startAppleAuthentication() async throws -> AppleIdentityToken {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func biometricPresence(_: BiometricPromptParams = .init()) async throws -> BiometricPresence {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func promptBiometrics(_: BiometricPromptParams = .init()) async throws -> BiometricAuthentication {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func prepareDeviceAttestation(_: DeviceAttestParams) async throws -> DeviceAttestationProof {
    throw ClerkJSCoreError.unsupportedPlatform
  }

  public func prepareDeviceAssertion(_: DeviceAttestParams) async throws -> DeviceAssertionProof {
    throw ClerkJSCoreError.unsupportedPlatform
  }
  #else
  private let runtime: JSRuntime
  private let sdkVersion: String
  private let resourceCache: ClerkJSResourceCache?
  private let oauthRedirectURL: URL
  private let proxyURL: URL?

  public init(
    sdkVersion: String = ClerkJSRuntime.sdkVersion,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil,
    oauthRedirectURL: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    proxyURL: URL? = nil,
    appAttestKeyIdStore: ClerkJSAppAttestKeyIdStore = .memory()
  ) {
    self.sdkVersion = sdkVersion
    self.resourceCache = resourceCache
    self.oauthRedirectURL = oauthRedirectURL
    self.proxyURL = proxyURL
    runtime = JSRuntime(tokenCache: tokenCache)
    runtime.host.resourceCache = resourceCache
    runtime.host.oauth.redirectURL = oauthRedirectURL
    runtime.host.appAttest.keyIdStore = appAttestKeyIdStore
  }

  var oauthSession: ClerkJSOAuthSession {
    runtime.host.oauth
  }

  var appleCeremony: ClerkJSAppleCeremony {
    runtime.host.apple
  }

  var biometricCeremony: ClerkJSBiometricCeremony {
    runtime.host.biometrics
  }

  var appAttestCeremony: ClerkJSAppAttestCeremony {
    runtime.host.appAttest
  }

  public var lastFAPIClientJSON: Data? {
    runtime.lastClientJSON
  }

  public var lastFAPIEnvironmentJSON: Data? {
    runtime.lastEnvironmentJSON
  }

  public var lastClientToken: String? {
    runtime.lastClientToken
  }

  public var lastStateJSON: Data? {
    runtime.lastStateJSON
  }

  public func observeState(_ handler: (@Sendable (Data) -> Void)?) {
    runtime.observeState(handler)
  }

  public func dispose() async {
    await runtime.dispose()
  }

  public func load(publishableKey: String) async throws {
    let pk = try Self.jsonString(publishableKey)
    let version = try Self.jsonString(sdkVersion)
    let generation = try Self.jsonString(generation)
    let proxy = try Self.jsonString(proxyURL?.absoluteString ?? "")
    let allowedProtocol = try Self.jsonString(Self.oauthAllowedRedirectProtocol(from: oauthRedirectURL))
    let oauthTransport = Self.oauthTransportInstallSource(redirectURL: oauthRedirectURL)
    _ = try await runtime.evaluateJSON("""
      (async function() {
        if (!globalThis.__clerkEmbeddedCore) {
          globalThis.__clerkEmbeddedCore = ClerkEmbedded.createEmbeddedClerk({
            protocolVersion: 1,
            generation: \(generation),
            publishableKey: \(pk),
            sdkVersion: \(version),
            options: {
              proxyUrl: \(proxy) || undefined,
              allowedRedirectProtocols: [\(allowedProtocol)],
              __internal_oauthTransport: \(oauthTransport)
            }
          }, {
            getToken: __clerkNativeGetToken,
            saveToken: __clerkNativeSaveToken,
            getCachedResources: __clerkNativeGetCachedResources,
            saveCachedResources: function(value) { return __clerkNativeSaveCachedResources(JSON.stringify(value)); },
            publish: function(state) { __clerkNativePublishState(JSON.stringify(state)); }
          });
          var clerk = globalThis.__clerkEmbeddedCore.clerk;
          globalThis.__clerkInstance = clerk;
          \(Self.passkeyHookInstallSource)
          \(Self.appleHookInstallSource)
          \(Self.biometricHookInstallSource)
          \(Self.appAttestHookInstallSource)
        }
        await globalThis.__clerkEmbeddedCore.load();
        return true;
      })()
      """)
  }

  public func evaluateJSON(_ js: String) async throws -> String {
    try await runtime.evaluateJSON(js)
  }

  public func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    let data = try JSONEncoder().encode(invocation)
    guard let json = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument("invocation")
    }
    do {
      let result = try await runtime.invokeJSON(receiver: "__clerkEmbeddedCore", method: "invoke", argumentsJSON: "[\(json)]")
      return try JSONDecoder().decode(JSONValue.self, from: Data(result.utf8))
    } catch let ClerkJSCoreError.javascript(message) {
      throw ClerkJSError.parse(message)
    }
  }

  public func call(methodPath: String, args: some Encodable) async throws -> String {
    let data = try JSONEncoder().encode(args)
    guard let argsJSON = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument("args")
    }
    let path = try Self.jsonString(methodPath)
    let script = """
      (function() {
        var parts = \(path).split('.');
        var receiver = globalThis;
        var fn = globalThis;
        for (var i = 0; i < parts.length; i++) {
          receiver = fn;
          fn = fn[parts[i]];
        }
        if (typeof fn !== 'function') {
          throw new Error('Not a function: ' + \(path));
        }
        function rejectReason(error) {
          var first = error && Array.isArray(error.errors) ? error.errors[0] : null;
          var code = first && first.code
            ? String(first.code)
            : (error && error.code ? String(error.code) : '');
          var message = first && (first.long_message || first.message)
            ? String(first.long_message || first.message)
            : (error && error.message ? String(error.message) : '');
          var name = error && error.name ? String(error.name) : 'js_error';
          var text = code || message || name;
          if (code && message && message.indexOf(code) === -1) {
            text = code + ': ' + message;
          }
          return new Error(text);
        }
        var result = fn.call(receiver, \(argsJSON));
        if (result && typeof result.then === 'function') {
          return result.then(function(value) {
            if (value === undefined || value === null || typeof value !== 'object') {
              return value === undefined ? true : value;
            }
            return true;
          }, function(error) {
            throw rejectReason(error);
          });
        }
        if (result === undefined || result === null || typeof result !== 'object') {
          return result === undefined ? true : result;
        }
        return true;
      })()
      """
    do {
      let result = try await runtime.evaluateJSON(script)
      _ = try? await publishCurrentState()
      return result
    } catch {
      _ = try? await publishCurrentState()
      throw error
    }
  }

  public func callReturning(methodPath: String, args: some Encodable) async throws -> String {
    let data = try JSONEncoder().encode(args)
    guard let argsJSON = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument("args")
    }
    let path = try Self.jsonString(methodPath)
    let script = """
      (function() {
        var parts = \(path).split('.');
        var receiver = globalThis;
        var fn = globalThis;
        for (var i = 0; i < parts.length; i++) {
          receiver = fn;
          fn = fn[parts[i]];
        }
        if (typeof fn !== 'function') {
          throw new Error('Not a function: ' + \(path));
        }
        function rejectReason(error) {
          var first = error && Array.isArray(error.errors) ? error.errors[0] : null;
          var code = first && first.code
            ? String(first.code)
            : (error && error.code ? String(error.code) : '');
          var message = first && (first.long_message || first.message)
            ? String(first.long_message || first.message)
            : (error && error.message ? String(error.message) : '');
          var name = error && error.name ? String(error.name) : 'js_error';
          var text = code || message || name;
          if (code && message && message.indexOf(code) === -1) {
            text = code + ': ' + message;
          }
          return new Error(text);
        }
        function serialize(value) {
          if (value === undefined) {
            return null;
          }
          if (value === null || typeof value !== 'object') {
            return value;
          }
          try {
            return JSON.parse(JSON.stringify(value));
          } catch (error) {
            throw rejectReason(error);
          }
        }
        var result = fn.call(receiver, \(argsJSON));
        if (result && typeof result.then === 'function') {
          return result.then(serialize, function(error) {
            throw rejectReason(error);
          });
        }
        return serialize(result);
      })()
      """
    do {
      let result = try await runtime.evaluateJSON(script)
      _ = try? await publishCurrentState()
      return result
    } catch {
      _ = try? await publishCurrentState()
      throw error
    }
  }

  public func callOnResourceReturning(
    factoryPath: String,
    id: String,
    method: String,
    argsJSON: String
  ) async throws -> String {
    let path = try Self.jsonString(factoryPath)
    let resourceId = try Self.jsonString(id)
    let methodName = try Self.jsonString(method)
    let script = """
      (function() {
        var parts = \(path).split('.');
        var receiver = globalThis;
        var fn = globalThis;
        for (var i = 0; i < parts.length; i++) {
          receiver = fn;
          fn = fn[parts[i]];
        }
        if (typeof fn !== 'function') {
          throw new Error('Not a function: ' + \(path));
        }
        function rejectReason(error) {
          var first = error && Array.isArray(error.errors) ? error.errors[0] : null;
          var code = first && first.code
            ? String(first.code)
            : (error && error.code ? String(error.code) : '');
          var message = first && (first.long_message || first.message)
            ? String(first.long_message || first.message)
            : (error && error.message ? String(error.message) : '');
          var name = error && error.name ? String(error.name) : 'js_error';
          var text = code || message || name;
          if (code && message && message.indexOf(code) === -1) {
            text = code + ': ' + message;
          }
          return new Error(text);
        }
        function serialize(value) {
          if (value === undefined) {
            return null;
          }
          if (value === null || typeof value !== 'object') {
            return value;
          }
          try {
            return JSON.parse(JSON.stringify(value));
          } catch (error) {
            throw rejectReason(error);
          }
        }
        function invoke(resource) {
          var method = \(methodName);
          if (!resource || typeof resource[method] !== 'function') {
            throw new Error('Not a function: ' + method);
          }
          var result = resource[method](\(argsJSON));
          if (result && typeof result.then === 'function') {
            return result.then(serialize, function(error) {
              throw rejectReason(error);
            });
          }
          return serialize(result);
        }
        var resource = fn.call(receiver, \(resourceId));
        if (resource && typeof resource.then === 'function') {
          return resource.then(invoke, function(error) {
            throw rejectReason(error);
          });
        }
        return invoke(resource);
      })()
      """
    do {
      let result = try await runtime.evaluateJSON(script)
      _ = try? await publishCurrentState()
      return result
    } catch {
      _ = try? await publishCurrentState()
      throw error
    }
  }

  public func callOnResourceSteps(
    receiverPath: String,
    receiverArgJSON: String,
    stepsJSON: String
  ) async throws -> String {
    let path = try Self.jsonString(receiverPath)
    let script = """
      (function() {
        var parts = \(path).split('.');
        var receiver = globalThis;
        var fn = globalThis;
        for (var i = 0; i < parts.length; i++) {
          receiver = fn;
          fn = fn[parts[i]];
        }
        function rejectReason(error) {
          var first = error && Array.isArray(error.errors) ? error.errors[0] : null;
          var code = first && first.code
            ? String(first.code)
            : (error && error.code ? String(error.code) : '');
          var message = first && (first.long_message || first.message)
            ? String(first.long_message || first.message)
            : (error && error.message ? String(error.message) : '');
          var name = error && error.name ? String(error.name) : 'js_error';
          var text = code || message || name;
          if (code && message && message.indexOf(code) === -1) {
            text = code + ': ' + message;
          }
          return new Error(text);
        }
        function serialize(value) {
          if (value === undefined) {
            return null;
          }
          if (value === null || typeof value !== 'object') {
            return value;
          }
          try {
            return JSON.parse(JSON.stringify(value));
          } catch (error) {
            throw rejectReason(error);
          }
        }
        function applySteps(resource, stepIndex, steps) {
          if (stepIndex >= steps.length) {
            return serialize(resource);
          }
          var step = steps[stepIndex];
          if (step.pick) {
            var items = resource[step.pick] || [];
            var picked = null;
            for (var i = 0; i < items.length; i++) {
              if (items[i] && items[i].id === step.findId) {
                picked = items[i];
                break;
              }
            }
            if (!picked) {
              throw new Error('Resource not found: ' + step.findId);
            }
            return applySteps(picked, stepIndex + 1, steps);
          }
          if (!resource || typeof resource[step.method] !== 'function') {
            throw new Error('Not a function: ' + step.method);
          }
          var result = resource[step.method](step.args);
          function next(value) {
            var nextResource = value;
            if (step.findId) {
              var items = Array.isArray(value) ? value : (value && value.data ? value.data : []);
              nextResource = null;
              for (var i = 0; i < items.length; i++) {
                if (items[i] && items[i].id === step.findId) {
                  nextResource = items[i];
                  break;
                }
              }
              if (!nextResource) {
                throw new Error('Resource not found: ' + step.findId);
              }
            }
            return applySteps(nextResource, stepIndex + 1, steps);
          }
          if (result && typeof result.then === 'function') {
            return result.then(next, function(error) {
              throw rejectReason(error);
            });
          }
          return next(result);
        }
        var steps = \(stepsJSON);
        var start;
        if (typeof fn === 'function') {
          start = fn.call(receiver, \(receiverArgJSON));
        } else if (fn === undefined || fn === null) {
          throw new Error('Not a function: ' + \(path));
        } else {
          start = fn;
        }
        if (start && typeof start.then === 'function') {
          return start.then(function(resource) {
            return applySteps(resource, 0, steps);
          }, function(error) {
            throw rejectReason(error);
          });
        }
        return applySteps(start, 0, steps);
      })()
      """
    do {
      let result = try await runtime.evaluateJSON(script)
      _ = try? await publishCurrentState()
      return result
    } catch {
      _ = try? await publishCurrentState()
      throw error
    }
  }

  private func publishCurrentState() async throws -> Bool {
    _ = try await runtime.evaluateJSON("globalThis.__clerkEmbeddedCore ? globalThis.__clerkEmbeddedCore.snapshot() : null")
    return true
  }

  static let resourceCacheInstallSource = """
    clerk.__internal_getCachedResources = async function() {
      var cached = await __clerkNativeGetCachedResources();
      return cached || { client: null, environment: null };
    };
    clerk.addListener(function() {
      var client = null;
      var environment = null;
      try {
        if (clerk.client && typeof clerk.client.__internal_toSnapshot === 'function') {
          client = clerk.client.__internal_toSnapshot();
        }
      } catch (e) {}
      try {
        if (clerk.__internal_environment && typeof clerk.__internal_environment.__internal_toSnapshot === 'function') {
          environment = clerk.__internal_environment.__internal_toSnapshot();
        }
      } catch (e) {}
      __clerkNativeSaveCachedResources(JSON.stringify({ client: client, environment: environment }));
    });
    """

  static let passkeyHookInstallSource = "ClerkEmbedded.installPasskeyHooks(clerk, { createPublicCredentials: __clerkNativeCreatePublicCredentials, getPublicCredentials: __clerkNativeGetPublicCredentials });"

  static let appleHookInstallSource = "ClerkEmbedded.installAppleHooks(clerk, { startAppleAuthentication: __clerkNativeAppleSignIn });"

  static let biometricHookInstallSource = "ClerkEmbedded.installBiometricHooks(clerk, { biometricPresence: __clerkNativeBiometricPresence, promptBiometrics: __clerkNativePromptBiometrics });"

  static let appAttestHookInstallSource = "ClerkEmbedded.installAppAttestHooks(clerk, { prepareDeviceAttestation: __clerkNativePrepareDeviceAttestation, prepareDeviceAssertion: __clerkNativePrepareDeviceAssertion });"

  public func startAppleAuthentication() async throws -> AppleIdentityToken {
    switch await appleCeremony.start(payload: "{}") {
    case .success(let identity):
      return identity
    case .failure(let error):
      if error.code == ClerkJSAppleError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSAppleError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("appleIdentity")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func biometricPresence(_ params: BiometricPromptParams = .init()) async throws -> BiometricPresence {
    switch await biometricCeremony.presence(payload: params.json) {
    case .success(let presence):
      return presence
    case .failure(let error):
      if error.code == ClerkJSBiometricError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("biometrics")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func promptBiometrics(_ params: BiometricPromptParams = .init()) async throws -> BiometricAuthentication {
    switch await biometricCeremony.prompt(payload: params.json) {
    case .success(let authentication):
      return authentication
    case .failure(let error):
      if error.code == ClerkJSBiometricError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSBiometricError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("biometrics")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  public func prepareDeviceAttestation(_ params: DeviceAttestParams) async throws -> DeviceAttestationProof {
    try await mapAppAttest(appAttestCeremony.attest(payload: params.json))
  }

  public func prepareDeviceAssertion(_ params: DeviceAttestParams) async throws -> DeviceAssertionProof {
    try await mapAppAttest(appAttestCeremony.assert(payload: params.json))
  }

  private func mapAppAttest<Value>(_ result: Result<Value, ClerkJSAppAttestError>) throws -> Value {
    switch result {
    case .success(let value):
      return value
    case .failure(let error):
      if error.code == ClerkJSAppAttestError.cancelled.code {
        throw ClerkJSCoreError.cancelled
      }
      if error.code == ClerkJSAppAttestError.invalidPayload.code {
        throw ClerkJSCoreError.invalidArgument("appAttest")
      }
      throw ClerkJSCoreError.javascript(error.message)
    }
  }

  static func oauthAllowedRedirectProtocol(from url: URL) -> String {
    let scheme = url.scheme ?? "clerk"
    return scheme.hasSuffix(":") ? scheme : "\(scheme):"
  }

  static func oauthTransportInstallSource(redirectURL: URL) -> String {
    let encoded: String = if let data = try? JSONEncoder().encode(redirectURL.absoluteString),
       let text = String(data: data, encoding: .utf8)
    {
      text
    } else {
      "\"\""
    }
    return """
      {
        getRedirectUrl: function() { return \(encoded); },
        open: async function(url, options) {
          var href = (url && typeof url.href === 'string') ? url.href : String(url);
          var callbackUrl = await __clerkNativeOAuthOpen(href, options);
          return { callbackUrl: callbackUrl };
        }
      }
      """
  }

  private static func jsonString(_ value: String) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let encoded = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument(value)
    }
    return encoded
  }
  #endif
}
