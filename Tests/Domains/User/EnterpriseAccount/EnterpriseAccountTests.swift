@testable import ClerkKit
import Foundation
import Testing

struct EnterpriseAccountTests {
  @Test
  func decodesAnEnterpriseConnectionWithoutALogo() throws {
    let account = try JSONDecoder.clerkDecoder.decode(
      EnterpriseAccount.self,
      from: Data(enterpriseAccountJSON(logoPublicUrl: "null").utf8)
    )

    #expect(account.enterpriseConnection.name == "Acme OIDC")
    #expect(account.enterpriseConnection.logoPublicUrl == nil)
  }

  @Test
  func decodesAnEnterpriseConnectionLogo() throws {
    let account = try JSONDecoder.clerkDecoder.decode(
      EnterpriseAccount.self,
      from: Data(enterpriseAccountJSON(logoPublicUrl: #""https://img.clerk.com/logo.png""#).utf8)
    )

    #expect(account.enterpriseConnection.logoPublicUrl == "https://img.clerk.com/logo.png")
  }

  private func enterpriseAccountJSON(logoPublicUrl: String) -> String {
    """
    {
      "id": "eac_123",
      "object": "enterprise_account",
      "protocol": "oauth",
      "provider": "oauth_custom_acme",
      "active": true,
      "email_address": "sam@acme.com",
      "first_name": "Sam",
      "last_name": null,
      "provider_user_id": "user_123",
      "last_authenticated_at": null,
      "public_metadata": {},
      "verification": null,
      "enterprise_connection_id": "ent_123",
      "enterprise_connection": {
        "id": "oauthcfg_123",
        "enterprise_connection_id": "ent_123",
        "protocol": "oauth",
        "provider": "oauth_custom_acme",
        "name": "Acme OIDC",
        "logo_public_url": \(logoPublicUrl),
        "domain": "acme.com",
        "domains": ["acme.com"],
        "active": true,
        "sync_user_attributes": true,
        "disable_additional_identifications": false,
        "created_at": 1700000000000,
        "updated_at": 1700000000000,
        "allow_subdomains": false,
        "allow_idp_initiated": false
      }
    }
    """
  }
}
