#if !os(watchOS)
@testable import ClerkJSCore
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSCoreTests {
  @Test
  func evaluateExposesClerkConstructorWithoutWindow() async throws {
    let runtime = ClerkJSRuntime()
    let clerkType = try await decodeJSONString(runtime.evaluateJSON("typeof Clerk"))
    #expect(clerkType == "function")
    let windowType = try await decodeJSONString(runtime.evaluateJSON("typeof window"))
    #expect(windowType == "undefined")
  }

  @Test
  func constructDoesNotThrow() async throws {
    let runtime = ClerkJSRuntime()
    let result = try await decodeJSONBool(
      runtime.evaluateJSON(
        "(function(){ new Clerk('\(mockPublishableKey)'); return true; })()"
      )
    )
    #expect(result)
  }

  @Test
  func polyfillsAreInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let fetchType = try await decodeJSONString(runtime.evaluateJSON("typeof fetch"))
    #expect(fetchType == "function")
    let online = try await decodeJSONBool(runtime.evaluateJSON("navigator.onLine === true"))
    #expect(online)
    let windowType = try await decodeJSONBool(runtime.evaluateJSON("typeof window === 'undefined'"))
    #expect(windowType)
    let searchEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new URLSearchParams('a=1').entries === 'function'")
    )
    #expect(searchEntries)
    let headerEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new Headers({a: '1'}).entries === 'function'")
    )
    #expect(headerEntries)
    let assignedPath = try await decodeJSONString(
      runtime.evaluateJSON(
        """
        (function(){
          var url = new URL('https://example.com');
          Object.assign(url, { pathname: 'v1/client' });
          return url.href;
        })()
        """
      )
    )
    #expect(assignedPath == "https://example.com/v1/client")
    let copiedSearch = try await decodeJSONString(
      runtime.evaluateJSON("new URLSearchParams(new URLSearchParams('a=1')).get('a')")
    )
    #expect(copiedSearch == "1")
    let copiedHeader = try await decodeJSONString(
      runtime.evaluateJSON("new Headers(new Headers({a: '1'})).get('a')")
    )
    #expect(copiedHeader == "1")
    let unpaddedAtob = try await decodeJSONString(runtime.evaluateJSON("atob('YQ')"))
    #expect(unpaddedAtob == "a")
    let unpaddedJSON = try await decodeJSONBool(
      runtime.evaluateJSON("JSON.parse(atob('eyJ4IjoxfQ')).x === 1")
    )
    #expect(unpaddedJSON)
  }

  @Test
  func generatedClientDecodesUnsignedFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let client = try JSONDecoder().decode(Client.self, from: data)
    #expect(client.id == "client_fixture")
    #expect(client.object == "client")
    #expect(client.signIn == nil)
    #expect(client.signUp == nil)
    #expect(client.sessions.isEmpty)
  }

  @Test
  func memoryTokenCacheRoundTripThroughHost() async throws {
    let cache = ClerkJSTokenCache.memory()
    let runtime = ClerkJSRuntime(tokenCache: cache)
    let saved = try await decodeJSONBool(
      runtime.evaluateJSON(
        """
        (async function() {
          await __clerkNativeSaveToken('host-jwt');
          return true;
        })()
        """
      )
    )
    #expect(saved)
    #expect(await cache.getToken() == "host-jwt")
    let read = try await decodeJSONString(runtime.evaluateJSON("(__clerkNativeGetToken())"))
    #expect(read == "host-jwt")
  }

  @Test
  func resourceCacheHookReturnsNullsWhenEmpty() async throws {
    let cache = ClerkJSResourceCache.memory()
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.resourceCacheInstallSource)
          return await clerk.__internal_getCachedResources();
        })()
        """
      )
    )
    #expect(payload.client == nil)
    #expect(payload.environment == nil)
  }

  @Test
  func resourceCacheHookReturnsSavedSnapshots() async throws {
    let cache = ClerkJSResourceCache.memory()
    let client = try #require(#"{"object":"client","id":"client_hook"}"#.data(using: .utf8))
    let environment = try #require(#"{"object":"environment","id":"env_hook"}"#.data(using: .utf8))
    await cache.save(ClerkJSCachedResources(client: client, environment: environment))
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.resourceCacheInstallSource)
          return await clerk.__internal_getCachedResources();
        })()
        """
      )
    )
    #expect(payload.client?.object == "client")
    #expect(payload.client?.id == "client_hook")
    #expect(payload.environment?.object == "environment")
    #expect(payload.environment?.id == "env_hook")
  }

  @Test
  func applyFAPIClientJSONHydratesJSSessions() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__clerkInstance = {
          client: {
            sessions: [],
            fromJSON: function(payload) {
              this.sessions = (payload.sessions || []).map(function(session) {
                return { id: session.id };
              });
              return this;
            }
          }
        };
        return true;
      })()
      """
    )
    let payload = try #require(
      #"{"object":"client","id":"client_apply","sessions":[{"id":"sess_apply"}]}"#.data(using: .utf8)
    )
    let applied = try await runtime.applyFAPIClientJSON(payload)
    #expect(applied)
    let count = try await JSONDecoder().decode(
      Int.self,
      from: Data((runtime.evaluateJSON("globalThis.__clerkInstance.client.sessions.length")).utf8)
    )
    #expect(count == 1)
    let prefix = try await decodeJSONString(
      runtime.evaluateJSON("globalThis.__clerkInstance.client.sessions[0].id.slice(0, 5)")
    )
    #expect(prefix == "sess_")
  }

  @Test
  func applyClientJSONScriptKeepsRawFAPIUserDataNull() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let script = try #require(NativeHost.applyClientJSONScript(data))
    let payload = try applyScriptPayload(script)
    let signIn = try #require(payload["sign_in"] as? [String: Any])
    #expect(signIn["user_data"] is NSNull)

    let normalized = try FAPIJSON.normalizeClientJSON(data)
    let normalizedPayload = try applyScriptPayload(#require(NativeHost.applyClientJSONScript(normalized)))
    let normalizedSignIn = try #require(normalizedPayload["sign_in"] as? [String: Any])
    let userData = try #require(normalizedSignIn["user_data"] as? [String: Any])
    #expect(userData["image_url"] as? String == "")
  }

  @Test
  func passkeyHooksAreInstalledOnClerkInstance() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyHookProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          return {
            create: typeof clerk.__internal_createPublicCredentials,
            get: typeof clerk.__internal_getPublicCredentials,
            supportedType: typeof clerk.__internal_isWebAuthnSupported,
            supported: clerk.__internal_isWebAuthnSupported(),
            autofillType: typeof clerk.__internal_isWebAuthnAutofillSupported,
            autofill: await clerk.__internal_isWebAuthnAutofillSupported(),
            platformType: typeof clerk.__internal_isWebAuthnPlatformAuthenticatorSupported,
            platform: await clerk.__internal_isWebAuthnPlatformAuthenticatorSupported()
          };
        })()
        """
      )
    )
    #expect(payload.create == "function")
    #expect(payload.get == "function")
    #expect(payload.supportedType == "function")
    #expect(payload.supported)
    #expect(payload.autofillType == "function")
    #expect(!payload.autofill)
    #expect(payload.platformType == "function")
    #expect(payload.platform)
  }

  @Test
  func passkeyCreateRejectsMissingRpIdWithoutCeremony() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          try {
            await clerk.__internal_createPublicCredentials({});
            return { threw: false, message: '' };
          } catch (error) {
            return { threw: true, message: String(error.message || error) };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.message == "Invalid public key or RpID")
  }

  @Test
  func passkeyGetRejectsMissingOptionsWithoutCeremony() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          try {
            await clerk.__internal_getPublicCredentials({});
            return { threw: false, message: '' };
          } catch (error) {
            return { threw: true, message: String(error.message || error) };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.message == "publicKeyCredential has not been provided")
  }

  @Test
  func passkeyNativeBridgeRejectsInvalidCreatePayload() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyCredentialReturn(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          var result = await clerk.__internal_createPublicCredentials({
            rp: { id: 'example.com' },
            user: { id: '', displayName: 'Ada' },
            challenge: new Uint8Array([1, 2, 3]).buffer
          });
          return {
            hasCredential: result.publicKeyCredential != null,
            errorCode: result.error && result.error.code,
            errorName: result.error && result.error.name
          };
        })()
        """
      )
    )
    #expect(!payload.hasCredential)
    #expect(payload.errorCode == "passkey_registration_failed")
    #expect(payload.errorName == "ClerkWebAuthnError")
  }

  @Test
  func resourceCacheHostPersistsSnapshots() async throws {
    let cache = ClerkJSResourceCache.memory()
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          await __clerkNativeSaveCachedResources(JSON.stringify({
            client: { object: 'client', id: 'client_saved' },
            environment: { object: 'environment', id: 'env_saved' }
          }));
          return await __clerkNativeGetCachedResources();
        })()
        """
      )
    )
    #expect(payload.client?.id == "client_saved")
    #expect(payload.environment?.id == "env_saved")
    let stored = await cache.load()
    #expect(stored.client != nil)
    #expect(stored.environment != nil)
  }
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}

private func decodeJSONBool(_ json: String) throws -> Bool {
  try JSONDecoder().decode(Bool.self, from: Data(json.utf8))
}

private struct CachedResourceJSON: Decodable {
  var object: String
  var id: String?
}

private struct CachedResourcesJSON: Decodable {
  var client: CachedResourceJSON?
  var environment: CachedResourceJSON?
}

private func decodeCachedResources(_ json: String) throws -> CachedResourcesJSON {
  try JSONDecoder().decode(CachedResourcesJSON.self, from: Data(json.utf8))
}

private struct PasskeyHookProbe: Decodable {
  var create: String
  var get: String
  var supportedType: String
  var supported: Bool
  var autofillType: String
  var autofill: Bool
  var platformType: String
  var platform: Bool
}

private struct PasskeyThrown: Decodable {
  var threw: Bool
  var message: String
}

private struct PasskeyCredentialReturn: Decodable {
  var hasCredential: Bool
  var errorCode: String?
  var errorName: String?
}

private func decodePasskeyHookProbe(_ json: String) throws -> PasskeyHookProbe {
  try JSONDecoder().decode(PasskeyHookProbe.self, from: Data(json.utf8))
}

private func decodePasskeyThrown(_ json: String) throws -> PasskeyThrown {
  try JSONDecoder().decode(PasskeyThrown.self, from: Data(json.utf8))
}

private func decodePasskeyCredentialReturn(_ json: String) throws -> PasskeyCredentialReturn {
  try JSONDecoder().decode(PasskeyCredentialReturn.self, from: Data(json.utf8))
}

private func applyScriptPayload(_ script: String) throws -> [String: Any] {
  let start = try #require(script.range(of: "JSON.parse(")?.upperBound)
  let rest = script[start...]
  let end = try #require(rest.range(of: "));")?.lowerBound)
  let jsonText = try JSONDecoder().decode(String.self, from: Data(String(rest[..<end]).utf8))
  return try #require(JSONSerialization.jsonObject(with: Data(jsonText.utf8)) as? [String: Any])
}
#endif
