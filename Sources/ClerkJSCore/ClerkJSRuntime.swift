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

  #if os(watchOS)
  public init(
    sdkVersion _: String = ClerkJSRuntime.sdkVersion,
    tokenCache _: ClerkJSTokenCache = .memory(),
    resourceCache _: ClerkJSResourceCache? = nil
  ) {}

  public var lastFAPIClientJSON: Data? {
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
  #else
  private let runtime: JSRuntime
  private let sdkVersion: String
  private let resourceCache: ClerkJSResourceCache?

  public init(
    sdkVersion: String = ClerkJSRuntime.sdkVersion,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil
  ) {
    self.sdkVersion = sdkVersion
    self.resourceCache = resourceCache
    runtime = JSRuntime(tokenCache: tokenCache)
    runtime.host.resourceCache = resourceCache
  }

  public var lastFAPIClientJSON: Data? {
    runtime.lastClientJSON
  }

  public func load(publishableKey: String) async throws {
    let pk = try Self.jsonString(publishableKey)
    let version = try Self.jsonString(sdkVersion)
    let script = """
      (async function() {
        if (typeof Clerk !== 'function') {
          throw new Error('Clerk constructor missing');
        }
        var clerk = new Clerk(\(pk));
        globalThis.__clerkInstance = clerk;
        clerk.__internal_onBeforeRequest(async function(requestInit) {
          requestInit.credentials = 'omit';
          if (requestInit.url && requestInit.url.searchParams) {
            requestInit.url.searchParams.append('_is_native', '1');
          }
          var jwt = await __clerkNativeGetToken();
          if (jwt) {
            requestInit.headers.set('authorization', jwt);
          }
          requestInit.headers.set('x-mobile', '1');
          requestInit.headers.set('x-ios-sdk-version', \(version));
        });
        clerk.__internal_onAfterResponse(async function(_, response) {
          var auth = response.headers.get('authorization');
          if (auth) {
            await __clerkNativeSaveToken(auth);
          }
        });
        \(resourceCache == nil ? "" : Self.resourceCacheInstallSource)
        await clerk.load({
          standardBrowser: false,
          experimental: {
            runtimeEnvironment: 'headless',
            rethrowOfflineNetworkErrors: true
          }
        });
        return true;
      })()
      """
    _ = try await runtime.evaluateJSON(script)
  }

  public func evaluateJSON(_ js: String) async throws -> String {
    try await runtime.evaluateJSON(js)
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
          var code = first && first.code ? String(first.code) : '';
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
      _ = try? await applyLastFAPIClientJSON()
      return result
    } catch {
      _ = try? await applyLastFAPIClientJSON()
      throw error
    }
  }

  func applyLastFAPIClientJSON() async throws -> Bool {
    guard let data = lastFAPIClientJSON else {
      return false
    }
    return try await applyFAPIClientJSON((try? FAPIJSON.normalizeClientJSON(data)) ?? data)
  }

  func applyFAPIClientJSON(_ data: Data) async throws -> Bool {
    guard let script = NativeHost.applyClientJSONScript(data) else {
      throw ClerkJSCoreError.invalidArgument("clientJSON")
    }
    return try await JSONDecoder().decode(Bool.self, from: Data(evaluateJSON(script).utf8))
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

  private static func jsonString(_ value: String) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let encoded = String(data: data, encoding: .utf8) else {
      throw ClerkJSCoreError.invalidArgument(value)
    }
    return encoded
  }
  #endif
}
