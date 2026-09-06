#if !os(watchOS)
import ClerkJSCore
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
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}

private func decodeJSONBool(_ json: String) throws -> Bool {
  try JSONDecoder().decode(Bool.self, from: Data(json.utf8))
}
#endif
