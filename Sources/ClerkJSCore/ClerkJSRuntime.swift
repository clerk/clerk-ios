import Foundation

public struct ClerkJSTokenCache: Sendable {
  public var getToken: @Sendable () async -> String
  public var saveToken: @Sendable (String) async -> Void

  public init(
    getToken: @escaping @Sendable () async -> String = { "" },
    saveToken: @escaping @Sendable (String) async -> Void = { _ in }
  ) {
    self.getToken = getToken
    self.saveToken = saveToken
  }
}

public final class ClerkJSRuntime: @unchecked Sendable {
  public static let sdkVersion = "1.5.3"

  #if os(watchOS)
  public init(
    sdkVersion _: String = ClerkJSRuntime.sdkVersion,
    tokenCache _: ClerkJSTokenCache = ClerkJSTokenCache()
  ) {}

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

  public init(
    sdkVersion: String = ClerkJSRuntime.sdkVersion,
    tokenCache: ClerkJSTokenCache = ClerkJSTokenCache()
  ) {
    self.sdkVersion = sdkVersion
    runtime = JSRuntime(tokenCache: tokenCache)
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
        clerk.__internal_onBeforeRequest(async function(requestInit) {
          requestInit.credentials = 'omit';
          if (requestInit.url && requestInit.url.searchParams) {
            requestInit.url.searchParams.append('_is_native', '1');
          }
          var jwt = await __clerkNativeGetToken();
          requestInit.headers.set('authorization', jwt || '');
          requestInit.headers.set('x-mobile', '1');
          requestInit.headers.set('x-ios-sdk-version', \(version));
        });
        clerk.__internal_onAfterResponse(async function(_, response) {
          var auth = response.headers.get('authorization');
          if (auth) {
            await __clerkNativeSaveToken(auth);
          }
        });
        await clerk.load({
          standardBrowser: false,
          experimental: {
            runtimeEnvironment: 'headless',
            rethrowOfflineNetworkErrors: true
          }
        });
        globalThis.__clerkInstance = clerk;
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
        return fn.apply(receiver, \(argsJSON));
      })()
      """
    return try await runtime.evaluateJSON(script)
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
