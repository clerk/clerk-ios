import ClerkKit
import Foundation

@MainActor enum PreviewFixtureProof {
  private final class Transport: CoreTransport {
    var receive: (@MainActor (JSONValue) -> Void)?
    func send(_: JSONValue) throws {}
    func close() {
      receive = nil
    }
  }

  static func run(directory: String) throws {
    let urls = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }
    precondition(urls.count == 8)
    for url in urls {
      let document = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url)).object()
      let runtime = CoreRuntime(transport: Transport())
      defer { runtime.close() }
      runtime.receive(.object([
        "kind": .string("ready"), "id": .string("preview"),
        "manifest": document["manifest"]!, "state": document["state"]!,
      ]))
      guard let clerk = try runtime.root("clerk", as: Clerk.self) else { preconditionFailure("Missing preview root") }
      precondition(clerk.loaded && !clerk.isInvalidated)
      if url.lastPathComponent == "signedOut.json" { precondition(clerk.user == nil); continue }
      precondition(clerk.user?.firstName == "First")
      precondition(clerk.user?.emailAddresses.first?.emailAddress == "user@email.com")
      precondition(clerk.user?.phoneNumbers.count == 3 && clerk.user?.passkeys.first?.name == "iCloud Keychain")
      let result = try document["results"]!.object()["Organization.getDomains"]!.object()
      let reference = try result["data"]!.array()[0]
      let domain = try runtime.resource(ResourceHandle.decodeReference(reference), as: OrganizationDomain.self)
      precondition(domain.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
      let sessions = try document["results"]!.object()["User.getSessions"]!.array()
      precondition(sessions.count == 2)
      let session = try runtime.resource(ResourceHandle.decodeReference(sessions[0]), as: SessionWithActivities.self)
      precondition(session.latestActivity.browserName == "Safari")
    }
    print("PASS: all 8 generated preview fixtures decode through the public Swift runtime, including domain dates and session activities")
  }
}
