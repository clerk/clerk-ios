import Foundation
import Mocker
import Testing

@testable import Clerk
@testable import Factory
@testable import Get

@Suite(.serialized) struct UserTests {
  
  init() {
    Container.shared.reset()
  }

  @Test func testPrimaryEmailAddress() {
    let user = User(
      id: "1",
      firstName: nil,
      lastName: nil,
      username: nil,
      hasImage: false,
      imageUrl: "",
      passkeys: [],
      primaryEmailAddressId: "1",
      emailAddresses: [
        .init(
          id: "1",
          emailAddress: "primary@email.com",
          verification: nil,
          linkedTo: nil
      ),
        .init(
          id: "2",
          emailAddress: "secondary@email.com",
          verification: nil,
          linkedTo: nil
        )
      ],
      primaryPhoneNumberId: nil,
      phoneNumbers: [],
      externalAccounts: [],
      enterpriseAccounts: [],
      passwordEnabled: false,
      totpEnabled: false,
      twoFactorEnabled: false,
      backupCodeEnabled: false,
      createOrganizationEnabled: false,
      createOrganizationsLimit: nil,
      deleteSelfEnabled: false,
      publicMetadata: nil,
      unsafeMetadata: nil,
      legalAcceptedAt: nil,
      lastSignInAt: nil,
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
    #expect(user.primaryEmailAddress?.emailAddress == "primary@email.com")
  }
  
  @Test func testHasNoPrimaryEmailAddress() {
    let user = User(
      id: "1",
      firstName: nil,
      lastName: nil,
      username: nil,
      hasImage: false,
      imageUrl: "",
      passkeys: [],
      primaryEmailAddressId: nil,
      emailAddresses: [],
      primaryPhoneNumberId: nil,
      phoneNumbers: [],
      externalAccounts: [],
      enterpriseAccounts: [],
      passwordEnabled: false,
      totpEnabled: false,
      twoFactorEnabled: false,
      backupCodeEnabled: false,
      createOrganizationEnabled: false,
      createOrganizationsLimit: nil,
      deleteSelfEnabled: false,
      publicMetadata: nil,
      unsafeMetadata: nil,
      legalAcceptedAt: nil,
      lastSignInAt: nil,
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
    
    #expect(user.primaryEmailAddress == nil)
  }
  
  @Test func testHasVerifiedEmailAddress() {
    let user = User(
      id: "1",
      firstName: nil,
      lastName: nil,
      username: nil,
      hasImage: false,
      imageUrl: "",
      passkeys: [],
      primaryEmailAddressId: nil,
      emailAddresses: [.init(
        id: "1",
        emailAddress: "user@email.com",
        verification: .init(
          status: .verified,
          strategy: nil,
          attempts: nil,
          expireAt: nil,
          error: nil,
          nonce: nil
        ),
        linkedTo: nil
      )],
      primaryPhoneNumberId: nil,
      phoneNumbers: [],
      externalAccounts: [],
      enterpriseAccounts: [],
      passwordEnabled: false,
      totpEnabled: false,
      twoFactorEnabled: false,
      backupCodeEnabled: false,
      createOrganizationEnabled: false,
      createOrganizationsLimit: nil,
      deleteSelfEnabled: false,
      publicMetadata: nil,
      unsafeMetadata: nil,
      legalAcceptedAt: nil,
      lastSignInAt: nil,
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
    
    #expect(user.hasVerifiedEmailAddress)
  }
  
  @Test func testDoesNotHaveVerifiedEmailAddress() {
    let user = User(
      id: "1",
      firstName: nil,
      lastName: nil,
      username: nil,
      hasImage: false,
      imageUrl: "",
      passkeys: [],
      primaryEmailAddressId: nil,
      emailAddresses: [.init(
        id: "1",
        emailAddress: "user@email.com",
        verification: .init(
          status: .unverified,
          strategy: nil,
          attempts: nil,
          expireAt: nil,
          error: nil,
          nonce: nil
        ),
        linkedTo: nil
      )],
      primaryPhoneNumberId: nil,
      phoneNumbers: [],
      externalAccounts: [],
      enterpriseAccounts: [],
      passwordEnabled: false,
      totpEnabled: false,
      twoFactorEnabled: false,
      backupCodeEnabled: false,
      createOrganizationEnabled: false,
      createOrganizationsLimit: nil,
      deleteSelfEnabled: false,
      publicMetadata: nil,
      unsafeMetadata: nil,
      legalAcceptedAt: nil,
      lastSignInAt: nil,
      createdAt: .distantPast,
      updatedAt: .distantPast
    )
    
    #expect(!user.hasVerifiedEmailAddress)
  }
}
