#if !os(watchOS)
import ClerkJSCore
@testable import ClerkKit
import Foundation
import Mocker

@MainActor
@discardableResult
func configureEmbeddedClerkForTesting(signedIn: Bool = true, configure: ((Clerk) throws -> Void)? = nil) async throws -> ClerkJSHost {
  await Clerk.disposeEngine()
  Mocker.removeAll()
  configureClerkForTesting()
  try configure?(Clerk.shared)
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockingURLProtocol.self]
  let host = ClerkJSHost(publishableKey: testPublishableKey, tokenCache: .init(getToken: { signedIn ? "fixture-client-jwt" : "" }, saveToken: { _ in }), sessionConfiguration: configuration)
  let environment = try ClerkJSHost.snapshotEnvironmentJSON()
  var client = try JSONSerialization.jsonObject(with: ClerkJSHost.snapshotSignedInClient()) as! [String: Any]
  var sessions = client["sessions"] as! [[String: Any]]
  let expiration = Date().addingTimeInterval(3600).timeIntervalSince1970.rounded(.down)
  let payload = try JSONSerialization.data(withJSONObject: ["sub": "user_fixture", "sid": "sess_fixture", "exp": expiration])
  let jwt = "eyJhbGciOiJSUzI1NiJ9." + payload.base64EncodedString().replacingOccurrences(of: "=", with: "") + ".signature"
  sessions[0]["expire_at"] = expiration * 1000
  sessions[0]["abandon_at"] = expiration * 1000
  sessions[0]["last_active_token"] = ["object": "token", "jwt": jwt]
  client["sessions"] = sessions
  if !signedIn {
    client = ["object": "client", "sessions": [], "last_active_session_id": NSNull()]
  }
  let environmentObject = try JSONSerialization.jsonObject(with: environment)
  for (path, response) in [("/environment", environmentObject), ("/client", client), ("/client/sessions/sess_fixture/touch", sessions[0])] {
    let data = try JSONSerialization.data(withJSONObject: ["response": response])
    Mock(url: URL(string: mockBaseUrl.absoluteString + "/v1" + path)!, ignoreQuery: true, contentType: .json, statusCode: 200, data: [.get: data, .post: data]).register()
  }
  Clerk.engineClient = ClerkJSHostEngine(host: host, kit: Clerk.shared)
  try await host.load()
  Mocker.removeAll()
  let organization = Organization.mock
  let organizationData = try JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: nil))
  Mock(url: URL(string: mockBaseUrl.absoluteString + "/v1/organizations/" + organization.id)!, ignoreQuery: true, contentType: .json, statusCode: 200, data: [.get: organizationData]).register()
  return host
}
#endif
