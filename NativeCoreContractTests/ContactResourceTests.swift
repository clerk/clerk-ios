import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct ContactResourceTests {
  @Test func deletionUpdatesTheUserAndPreservesReadableHeldContacts() async throws {
    let host = try ContactCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let email = try #require(user.emailAddresses.first)
    let phone = try #require(user.phoneNumbers.first)
    let account = try #require(user.externalAccounts.first)

    try await email.destroy()
    #expect(user.emailAddresses.isEmpty)
    #expect(email.emailAddress == "contact@example.com")
    try await phone.destroy()
    #expect(user.phoneNumbers.isEmpty)
    #expect(phone.phoneNumber == "+15555550123")
    try await account.destroy()
    #expect(user.externalAccounts.isEmpty)
    #expect(account.emailAddress == "provider@example.com")
    #expect(account.provider.rawValue == "google")
    #expect(host.deletedCollections == ["email_addresses", "phone_numbers", "external_accounts"])
    try await clerk.signIn.reset()
    #expect(clerk.loaded)
    #expect(clerk.user?.id == user.id)
  }
}

@MainActor private final class ContactCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  private var client: [String: JSONValue]
  private(set) var deletedCollections: [String] = []

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    let verification: JSONValue = .object(["status": .string("verified"), "strategy": .string("email_code"), "attempts": .null, "expire_at": .null, "error": .null, "verified_at_client": .null])
    user["email_addresses"] = .array([.object(["object": .string("email_address"), "id": .string("email_contact"), "email_address": .string("contact@example.com"), "matches_sso_connection": .bool(false), "linked_to": .array([]), "verification": verification])])
    user["phone_numbers"] = .array([.object(["object": .string("phone_number"), "id": .string("phone_contact"), "phone_number": .string("+15555550123"), "reserved_for_second_factor": .bool(false), "default_second_factor": .bool(false), "linked_to": .array([]), "verification": verification])])
    user["external_accounts"] = .array([.object(["object": .string("external_account"), "id": .string("account_contact"), "provider": .string("google"), "identification_id": .string("idn_contact"), "provider_user_id": .string("provider_contact"), "approved_scopes": .string("profile"), "email_address": .string("provider@example.com"), "first_name": .string("Test"), "last_name": .string("User"), "image_url": .string(""), "public_metadata": .object([:]), "verification": verification])])
    session["user"] = .object(user)
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try #require(args["url"]).url()
    let method = try URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "_method" })?.value ?? (#require(args["method"]).string())
    guard method == "DELETE", url.path.hasPrefix("/v1/me/") else { return try await base.perform(capability, arguments: arguments) }
    let collection = url.deletingLastPathComponent().lastPathComponent
    #expect(["email_addresses", "phone_numbers", "external_accounts"].contains(collection))
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    let item = try #require(user[collection]).array()[0].object()
    #expect(item["id"] == .string(url.lastPathComponent))
    user[collection] = .array([])
    session["user"] = .object(user)
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
    deletedCollections.append(collection)
    let receipt: JSONValue = .object(["object": item["object"]!, "id": item["id"]!, "deleted": .bool(true)])
    let body = try JSONEncoder().encode(JSONValue.object(["response": receipt, "client": .object(client)]))
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(String(decoding: body, as: UTF8.self))])
  }
}
