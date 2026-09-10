import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct PaymentMethodTests {
  @Test(arguments: [false, true])
  func payerCollectionsPreservePaymentMethodFields(organization: Bool) async throws {
    let host = try PaymentMethodCapabilities(organization: organization)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { clerk.close() }
    let params = GetPaymentMethodsParams(initialPage: 3, pageSize: 10)
    let result = try await organization
      ? #require(clerk.organization).getPaymentMethods(params)
      : #require(clerk.user).getPaymentMethods(params)
    #expect(result.totalCount == 21)
    #expect(result.data.count == 2)
    let method = try #require(result.data.first)
    #expect(method.id == "pm_1")
    #expect(method.last4 == "4242")
    #expect(method.cardType == "visa")
    #expect(method.paymentType == "card")
    #expect(method.status == .active)
    #expect(method.isDefault == true)
    #expect(method.isRemovable == true)
    #expect(method.walletType == .null)
    #expect(method.expiryMonth == .value(12))
    #expect(method.expiryYear == .value(2030))
    #expect(method.createdAt == .value(Date(timeIntervalSince1970: 1_700_000_000)))
    #expect(method.updatedAt == .value(Date(timeIntervalSince1970: 1_700_000_001)))
    #expect(result.data[1].status == .unrecognized("future_status"))
    #expect(result.data[1].last4 == nil)
    #expect(result.data[1].expiryMonth == .null)
    #expect(host.requested)
  }
}

@MainActor private final class PaymentMethodCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let organization: Bool
  private(set) var requested = false

  init(organization: Bool) throws {
    self.organization = organization
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    var client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    let membership = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"object":"organization_membership","id":"orgmem_native","role":"org:member","role_name":"Member","permissions":[],"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000,"public_user_data":{"user_id":"user_native","identifier":"test@example.com","image_url":"","has_image":false},"organization":{"object":"organization","id":"org_payment","name":"Payment Org","slug":"payment-org","image_url":"","has_image":false,"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000}}"#.utf8))
    user["organization_memberships"] = .array([membership])
    session["user"] = .object(user)
    session["last_active_organization_id"] = .string("org_payment")
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try #require(args["url"]).url()
    guard url.path.hasSuffix("/billing/payment_methods") else { return try await base.perform(capability, arguments: arguments) }
    #expect(url.path == (organization ? "/v1/organizations/org_payment/billing/payment_methods" : "/v1/me/billing/payment_methods"))
    #expect(args["method"] == .string("GET"))
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    for (name, value) in [("limit", "10"), ("offset", "20"), ("_clerk_session_id", "sess_native")] {
      #expect(query.contains { $0.name == name && $0.value == value })
    }
    requested = true
    let body = #"{"response":{"total_count":21,"data":[{"object":"commerce_payment_method","id":"pm_1","last4":"4242","payment_type":"card","card_type":"visa","is_default":true,"is_removable":true,"status":"active","wallet_type":null,"expiry_year":2030,"expiry_month":12,"created_at":1700000000000,"updated_at":1700000001000},{"object":"commerce_payment_method","id":"pm_2","last4":null,"card_type":null,"status":"future_status","expiry_month":null}]}}"#
    return .object(["status": .number(200), "headers": .object([:]), "body": .string(body)])
  }
}
