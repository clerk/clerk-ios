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
#endif
