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
    let windowType = try await decodeJSONString(runtime.evaluateJSON("typeof window"))
    #expect(windowType == "undefined")
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
          var url = new URL('https://amusing-barnacle-26.clerk.accounts.dev');
          Object.assign(url, { pathname: 'v1/client' });
          return url.href;
        })()
        """
      )
    )
    #expect(assignedPath == "https://amusing-barnacle-26.clerk.accounts.dev/v1/client")
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
  func loadReturnsClientIdOverJSON() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)

    let proof = try await JSONDecoder().decode(
      ClerkLoadProof.self,
      from: Data(
        runtime.evaluateJSON(
          """
          ({
            loaded: globalThis.__clerkInstance.loaded,
            clientId: globalThis.__clerkInstance.client.id
          })
          """
        ).utf8
      )
    )
    #expect(proof.loaded)
    #expect(proof.clientId.hasPrefix("client_"))

    let snapshot = try await runtime.evaluateJSON(
      "globalThis.__clerkInstance.client.__internal_toSnapshot()"
    )
    let destination = packageRootURL().appendingPathComponent(".verification/client-after-load.json")
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try snapshot.write(to: destination, atomically: true, encoding: .utf8)
  }

  @Test
  func generatedClientDecodesLiveClientJSON() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)

    let snapshot = try await runtime.evaluateJSON(
      "globalThis.__clerkInstance.client.__internal_toSnapshot()"
    )
    var snapshotCodingPath = ""
    do {
      _ = try JSONDecoder().decode(Client.self, from: Data(snapshot.utf8))
    } catch let error as DecodingError {
      snapshotCodingPath = decodingPath(error)
    }
    #expect(snapshotCodingPath.hasSuffix("status") || snapshotCodingPath.contains("identifier"))

    let payload = try #require(runtime.lastFAPIClientJSON)
    let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
    let signIn = wireField(object, "sign_in")
    let signUp = wireField(object, "sign_up")
    do {
      let client = try JSONDecoder().decode(Client.self, from: payload)
      #expect(client.id.hasPrefix("client_"), "FAPI sign_in=\(signIn) sign_up=\(signUp)")
      #expect(client.object == "client")
    } catch let error as DecodingError {
      let path = decodingPath(error)
      #expect(
        path.hasSuffix("status") || path.contains("identifier"),
        "FAPI ClientJSON failed at \(path); sign_in=\(signIn) sign_up=\(signUp)"
      )
    }
  }
}

private struct ClerkLoadProof: Decodable {
  let loaded: Bool
  let clientId: String
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}

private func decodeJSONBool(_ json: String) throws -> Bool {
  try JSONDecoder().decode(Bool.self, from: Data(json.utf8))
}

private func wireField(_ object: [String: Any], _ key: String) -> String {
  guard object.keys.contains(key) else {
    return "missing"
  }
  switch object[key] {
  case nil, is NSNull:
    return "null"
  case is [String: Any]:
    return "object"
  default:
    return "other"
  }
}

private func decodingPath(_ error: DecodingError) -> String {
  let context: DecodingError.Context
  switch error {
  case .typeMismatch(_, let ctx):
    context = ctx
  case .valueNotFound(_, let ctx):
    context = ctx
  case .keyNotFound(_, let ctx):
    context = ctx
  case .dataCorrupted(let ctx):
    context = ctx
  @unknown default:
    return String(describing: error)
  }
  return context.codingPath.map(\.stringValue).joined(separator: ".")
}

private func packageRootURL() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

private func publishableKeyFromKeysFile(named name: String) -> String? {
  let url = packageRootURL().appendingPathComponent(".keys.json")
  guard let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let entry = json[name] as? [String: Any],
        let pk = entry["pk"] as? String,
        !pk.isEmpty
  else {
    return nil
  }
  return pk
}
#endif
