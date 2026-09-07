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
    appAttestKeyIdStore _: ClerkJSAppAttestKeyIdStore = .memory()
  ) {}

  public var lastFAPIClientJSON: Data? {
    nil
  }

  public var lastFAPIEnvironmentJSON: Data? {
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

  public init(
    sdkVersion: String = ClerkJSRuntime.sdkVersion,
    tokenCache: ClerkJSTokenCache = .memory(),
    resourceCache: ClerkJSResourceCache? = nil,
    oauthRedirectURL: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    appAttestKeyIdStore: ClerkJSAppAttestKeyIdStore = .memory()
  ) {
    self.sdkVersion = sdkVersion
    self.resourceCache = resourceCache
    self.oauthRedirectURL = oauthRedirectURL
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

  public func load(publishableKey: String) async throws {
    let pk = try Self.jsonString(publishableKey)
    let version = try Self.jsonString(sdkVersion)
    let allowedProtocol = try Self.jsonString(Self.oauthAllowedRedirectProtocol(from: oauthRedirectURL))
    let oauthTransport = Self.oauthTransportInstallSource(redirectURL: oauthRedirectURL)
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
        \(Self.passkeyHookInstallSource)
        \(Self.appleHookInstallSource)
        \(Self.biometricHookInstallSource)
        \(Self.appAttestHookInstallSource)
        await clerk.load({
          standardBrowser: false,
          experimental: {
            runtimeEnvironment: 'headless',
            rethrowOfflineNetworkErrors: true
          },
          allowedRedirectProtocols: [\(allowedProtocol)],
          __internal_oauthTransport: \(oauthTransport)
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
    return try await applyFAPIClientJSON(data)
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

  static let passkeyHookInstallSource = """
    (function() {
      function bytesToBase64Url(value) {
        if (value == null) return '';
        if (typeof value === 'string') return value;
        var bytes;
        if (value instanceof ArrayBuffer) bytes = new Uint8Array(value);
        else if (value.buffer instanceof ArrayBuffer) {
          bytes = new Uint8Array(value.buffer, value.byteOffset || 0, value.byteLength || value.length);
        } else if (typeof value.length === 'number') bytes = new Uint8Array(value);
        else return '';
        var bin = '';
        for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
        return btoa(bin).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+$/g, '');
      }
      function base64UrlToBytes(value) {
        var base64 = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
        var pad = base64.length % 4;
        if (pad) base64 += '===='.slice(0, 4 - pad);
        var bin = atob(base64);
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return bytes.buffer;
      }
      function passkeyError(error, fallbackCode) {
        var err = new Error(error && error.message ? String(error.message) : String(error));
        err.name = (error && error.name) || 'ClerkWebAuthnError';
        err.code = error && error.code ? String(error.code) : fallbackCode;
        return err;
      }
      clerk.__internal_isWebAuthnSupported = function() { return true; };
      clerk.__internal_isWebAuthnAutofillSupported = function() { return Promise.resolve(false); };
      clerk.__internal_isWebAuthnPlatformAuthenticatorSupported = function() {
        return Promise.resolve(true);
      };
      clerk.__internal_createPublicCredentials = async function(publicKey) {
        if (!publicKey || !publicKey.rp || !publicKey.rp.id) {
          throw new Error('Invalid public key or RpID');
        }
        var payload = {
          challenge: bytesToBase64Url(publicKey.challenge),
          rpId: String(publicKey.rp.id),
          userId: bytesToBase64Url(publicKey.user && publicKey.user.id),
          displayName: String((publicKey.user && (publicKey.user.displayName || publicKey.user.name)) || ''),
          excludeCredentials: (publicKey.excludeCredentials || []).map(function(credential) {
            return bytesToBase64Url(credential.id);
          })
        };
        try {
          var credential = await __clerkNativeCreatePublicCredentials(JSON.stringify(payload));
          return {
            publicKeyCredential: {
              id: credential.id,
              rawId: base64UrlToBytes(credential.rawId),
              type: credential.type || 'public-key',
              authenticatorAttachment: credential.authenticatorAttachment || 'platform',
              response: {
                clientDataJSON: base64UrlToBytes(credential.response.clientDataJSON),
                attestationObject: base64UrlToBytes(credential.response.attestationObject),
                getTransports: function() {
                  return credential.response.transports || ['internal'];
                }
              }
            },
            error: null
          };
        } catch (error) {
          return { publicKeyCredential: null, error: passkeyError(error, 'passkey_registration_failed') };
        }
      };
      clerk.__internal_getPublicCredentials = async function(params) {
        var publicKeyOptions = params && params.publicKeyOptions;
        if (!publicKeyOptions) {
          throw new Error('publicKeyCredential has not been provided');
        }
        var payload = {
          challenge: bytesToBase64Url(publicKeyOptions.challenge),
          rpId: String(publicKeyOptions.rpId || ''),
          allowCredentials: (publicKeyOptions.allowCredentials || []).map(function(credential) {
            return bytesToBase64Url(credential.id);
          })
        };
        if (!payload.rpId) {
          throw new Error('Invalid public key or RpID');
        }
        try {
          var credential = await __clerkNativeGetPublicCredentials(JSON.stringify(payload));
          return {
            publicKeyCredential: {
              id: credential.id,
              rawId: base64UrlToBytes(credential.rawId),
              type: credential.type || 'public-key',
              authenticatorAttachment: credential.authenticatorAttachment || 'platform',
              response: {
                clientDataJSON: base64UrlToBytes(credential.response.clientDataJSON),
                authenticatorData: base64UrlToBytes(credential.response.authenticatorData),
                signature: base64UrlToBytes(credential.response.signature),
                userHandle: credential.response.userHandle
                  ? base64UrlToBytes(credential.response.userHandle)
                  : null
              }
            },
            error: null
          };
        } catch (error) {
          return { publicKeyCredential: null, error: passkeyError(error, 'passkey_retrieval_failed') };
        }
      };
    })();
    """

  static let appleHookInstallSource = """
    clerk.__internal_startAppleAuthentication = async function(params) {
      var payload = '{}';
      if (params && typeof params === 'object') {
        payload = JSON.stringify(params);
      }
      return await __clerkNativeAppleSignIn(payload);
    };
    """

  static let biometricHookInstallSource = """
    clerk.__internal_biometricPresence = async function(params) {
      var payload = '{}';
      if (params && typeof params === 'object') {
        payload = JSON.stringify(params);
      }
      return await __clerkNativeBiometricPresence(payload);
    };
    clerk.__internal_promptBiometrics = async function(params) {
      var payload = '{}';
      if (params && typeof params === 'object') {
        payload = JSON.stringify(params);
      }
      return await __clerkNativePromptBiometrics(payload);
    };
    """

  static let appAttestHookInstallSource = """
    clerk.__internal_prepareDeviceAttestation = async function(params) {
      var payload = '{}';
      if (params && typeof params === 'object') {
        payload = JSON.stringify(params);
      }
      return await __clerkNativePrepareDeviceAttestation(payload);
    };
    clerk.__internal_prepareDeviceAssertion = async function(params) {
      var payload = '{}';
      if (params && typeof params === 'object') {
        payload = JSON.stringify(params);
      }
      return await __clerkNativePrepareDeviceAssertion(payload);
    };
    """

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
        open: async function(url) {
          var href = (url && typeof url.href === 'string') ? url.href : String(url);
          var callbackUrl = await __clerkNativeOAuthOpen(href);
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
