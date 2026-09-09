#if os(iOS) || os(macOS)
import ClerkKit
import Foundation

@MainActor
private final class PreviewTransport: CoreTransport {
  var receive: (@MainActor (JSONValue) -> Void)?
  let results: [String: JSONValue]
  let delay: Duration?

  init(results: [String: JSONValue], delay: Duration?) {
    self.results = results
    self.delay = delay
  }

  func send(_ message: JSONValue) throws {
    let values = try message.object()
    guard values["kind"] == .string("invoke"), let id = values["id"] else { return }
    let operation = try (values["operation"] ?? .undefined).string()
    var reply: [String: JSONValue] = ["kind": .string("complete"), "id": id]
    if let result = results[operation] {
      reply["result"] = result
    } else {
      reply["failure"] = .object([
        "kind": .string("bridge"), "code": .string("preview_read_only"),
        "message": .string("This operation is unavailable in the preview fixture."),
      ])
    }
    let response = JSONValue.object(reply)
    Task { [weak self] in
      if let delay = self?.delay { try? await Task.sleep(for: delay) }
      self?.receive?(response)
    }
  }

  func close() {
    receive = nil
  }
}

enum ClerkPreviewVariant: String {
  case `default`, signedOut, profile, members, domains, enrollment, completeProfile, longOrganizationName
}

@MainActor
private final class PreviewFixture {
  static let standard = PreviewFixture(.default)
  static let longOrganizationName = PreviewFixture(.longOrganizationName)
  static let enrollment = PreviewFixture(.enrollment)
  let clerk: Clerk
  let runtime: CoreRuntime
  let resources: [[String: JSONValue]]

  init(_ variant: ClerkPreviewVariant, delay: Duration? = nil) {
    do {
      guard let url = Bundle.module.url(forResource: variant.rawValue, withExtension: "json", subdirectory: "Preview")
        ?? Bundle.module.url(forResource: variant.rawValue, withExtension: "json")
      else { preconditionFailure("Missing generated preview fixture") }
      let document = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url)).object()
      let state = try (document["state"] ?? .undefined).object()
      resources = try (state["resources"] ?? .undefined).array().map { try $0.object() }
      var results = try (document["results"] ?? .undefined).object()
      let roots = try (state["roots"] ?? .undefined).object()
      if let user = roots["user"], user != .null { results["User.reload"] = .object(["$ref": user]) }
      let transport = PreviewTransport(results: results, delay: delay)
      runtime = CoreRuntime(transport: transport)
      runtime.receive(.object([
        "kind": .string("ready"), "id": .string("preview"),
        "manifest": document["manifest"] ?? .undefined, "state": document["state"] ?? .undefined,
      ]))
      guard let root = try runtime.root("clerk", as: Clerk.self) else {
        preconditionFailure("Invalid generated preview fixture")
      }
      clerk = root
    } catch {
      preconditionFailure("Unable to decode generated preview fixture: \(error)")
    }
  }

  func resource<T: CoreResource>(_ type: T.Type, named name: String, id: String? = nil) -> T {
    do {
      guard let record = resources.first(where: { record in
        guard let handle = try? record["handle"]?.object(), handle["type"] == .string(name) else { return false }
        return id == nil || (try? record["state"]?.object()["id"]) == .string(id!)
      }) else { preconditionFailure("Missing preview resource: \(name)") }
      return try runtime.resource(ResourceHandle.decode(record["handle"] ?? .undefined), as: type)
    } catch { preconditionFailure("Invalid preview resource: \(error)") }
  }
}

extension Clerk {
  @MainActor static func preview(_ variant: ClerkPreviewVariant = .default, delay: Duration? = nil) -> Clerk {
    PreviewFixture(variant, delay: delay).clerk
  }
}

extension User { @MainActor static var mock: User {
  PreviewFixture.standard.clerk.user!
} }
extension Organization {
  @MainActor static var mock: Organization {
    PreviewFixture.standard.resource(Self.self, named: "Organization")
  }

  @MainActor static var previewLongName: Organization {
    PreviewFixture.longOrganizationName.resource(Self.self, named: "Organization")
  }
}

extension OrganizationDomain {
  @MainActor static var mock: OrganizationDomain {
    PreviewFixture.standard.resource(Self.self, named: "OrganizationDomain")
  }

  @MainActor static var previewEnrollment: OrganizationDomain {
    PreviewFixture.enrollment.resource(Self.self, named: "OrganizationDomain")
  }
}

extension EmailAddress { @MainActor static var mock: EmailAddress {
  PreviewFixture.standard.clerk.user!.emailAddresses[0]
} }
extension PhoneNumber {
  @MainActor static var mock: PhoneNumber {
    PreviewFixture.standard.clerk.user!.phoneNumbers[0]
  }

  @MainActor static var mockMfa: PhoneNumber {
    PreviewFixture.standard.clerk.user!.phoneNumbers[2]
  }
}

extension Passkey { @MainActor static var mock: Passkey {
  PreviewFixture.standard.clerk.user!.passkeys[0]
} }
extension ExternalAccount { @MainActor static var mockVerified: ExternalAccount {
  PreviewFixture.standard.clerk.user!.externalAccounts[0]
} }
extension SessionWithActivities { @MainActor static var mock: SessionWithActivities {
  PreviewFixture.standard.resource(Self.self, named: "SessionWithActivities")
} }
extension TOTP {
  static var mock: TOTP {
    .init(id: "1", secret: "1234567890", uri: "https://mock.com/totp", verified: true, backupCodes: ["123", "456"], createdAt: .distantPast, updatedAt: .distantPast)
  }
}
#endif
