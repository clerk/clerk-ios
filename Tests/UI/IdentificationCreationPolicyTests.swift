#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct IdentificationCreationPolicyTests {
  private func environment(enterpriseSSOEnabled: Bool?) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.userSettings.enterpriseSSO = enterpriseSSOEnabled.map { .init(enabled: $0) }
    return environment
  }

  private func user(enterpriseAccounts: [(accountActive: Bool, disableAdditionalIdentifications: Bool)]) -> User {
    var user = User.mock
    user.enterpriseAccounts = enterpriseAccounts.enumerated().map { index, account in
      EnterpriseAccount(
        id: "eac_\(index)",
        object: "enterprise_account",
        protocol: "saml",
        provider: "saml_okta",
        active: account.accountActive,
        emailAddress: "user@acme.com",
        publicMetadata: [:],
        enterpriseConnection: .init(
          id: "ent_\(index)",
          protocol: "saml",
          provider: "saml_okta",
          name: "Acme",
          domain: "acme.com",
          active: true,
          syncUserAttributes: false,
          disableAdditionalIdentifications: account.disableAdditionalIdentifications,
          createdAt: .distantPast,
          updatedAt: .distantPast,
          allowSubdomains: false,
          allowIdpInitiated: false
        )
      )
    }
    return user
  }

  @Test
  func anActiveEnterpriseAccountThatDisablesAdditionalIdentificationsBlocksAdding() {
    let user = user(enterpriseAccounts: [(accountActive: true, disableAdditionalIdentifications: true)])

    #expect(!environment(enterpriseSSOEnabled: true).allowsAddingIdentifications(for: user))
  }

  @Test
  func anInactiveEnterpriseAccountDoesNotBlockAdding() {
    let user = user(enterpriseAccounts: [(accountActive: false, disableAdditionalIdentifications: true)])

    #expect(environment(enterpriseSSOEnabled: true).allowsAddingIdentifications(for: user))
  }

  @Test
  func aConnectionThatAllowsAdditionalIdentificationsDoesNotBlockAdding() {
    let user = user(enterpriseAccounts: [(accountActive: true, disableAdditionalIdentifications: false)])

    #expect(environment(enterpriseSSOEnabled: true).allowsAddingIdentifications(for: user))
  }

  @Test(arguments: [false, nil] as [Bool?])
  func thePolicyIsIgnoredWhenEnterpriseSSOIsOff(enterpriseSSOEnabled: Bool?) {
    let user = user(enterpriseAccounts: [(accountActive: true, disableAdditionalIdentifications: true)])

    #expect(environment(enterpriseSSOEnabled: enterpriseSSOEnabled).allowsAddingIdentifications(for: user))
  }

  @Test
  func aUserWithoutEnterpriseAccountsCanAdd() {
    #expect(environment(enterpriseSSOEnabled: true).allowsAddingIdentifications(for: user(enterpriseAccounts: [])))
  }
}

#endif
