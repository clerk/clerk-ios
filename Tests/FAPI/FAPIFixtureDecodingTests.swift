@testable import ClerkKit
import Foundation
import Testing

struct FAPIFixtureDecodingTests {
  @Test func rolesWithNullDescriptions() throws {
    try decode(ClerkPaginatedResponse<RoleResource>.self, from: "fapi-organization-roles-page")
  }

  @Test func creditLedgerWithRFC3339CreatedAt() throws {
    try decode(ClerkPaginatedResponse<BillingCreditLedger>.self, from: "fapi-credit-history-page")
  }

  @Test func enterpriseAccountWithNullLogo() throws {
    try decode(EnterpriseAccount.self, from: "fapi-enterprise-account-without-logo")
  }

  @Test func sessionWithActorObject() throws {
    try decode(Session.self, from: "fapi-session-with-actor")
  }

  private func decode<Model: Decodable>(_: Model.Type, from fixture: String) throws {
    let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
    _ = try JSONDecoder.clerkDecoder.decode(Model.self, from: Data(contentsOf: url))
  }
}
