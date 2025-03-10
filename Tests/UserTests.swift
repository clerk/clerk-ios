import ConcurrencyExtras
import Factory
import Foundation
import Mocker
import Testing

@testable import Clerk

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct UserTests {

  @Test func testUserPrimaryEmailAddress() {
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
  
  @Test func testUserHasNoPrimaryEmailAddress() {
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
  
  @Test func testUserHasVerifiedEmailAddress() {
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
        verification: .mockEmailCodeVerifiedVerification,
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
  
  @Test func testUserDoesNotHaveVerifiedEmailAddress() {
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
        verification: .mockEmailCodeUnverifiedVerification,
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
  
  @Test func testUserHasPrimaryPhoneNumber() {
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
      primaryPhoneNumberId: "1",
      phoneNumbers: [
        .init(
          id: "1",
          phoneNumber: "5555550100",
          reservedForSecondFactor: false,
          defaultSecondFactor: false,
          verification: nil,
          linkedTo: nil,
          backupCodes: nil
        ),
        .init(
          id: "2",
          phoneNumber: "5555550110",
          reservedForSecondFactor: false,
          defaultSecondFactor: false,
          verification: nil,
          linkedTo: nil,
          backupCodes: nil
        )
      ],
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
    
    #expect(user.primaryPhoneNumber?.phoneNumber == "5555550100")
  }
  
  @Test func testUserDoesNotHavePrimaryPhoneNumber() {
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
    
    #expect(user.primaryPhoneNumber == nil)
  }
  
  @Test func testUserHasVerifiedPhoneNumber() {
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
      phoneNumbers: [.mock],
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
    
    #expect(user.hasVerifiedPhoneNumber)
  }
  
  @Test func testUserDoesNotHaveVerifiedPhoneNumber() {
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
        verification: .mockPhoneCodeUnverifiedVerification,
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
    
    #expect(!user.hasVerifiedPhoneNumber)
  }
  
  @Test func testUserVerifiedExternalAccounts() {
    #expect(User.mock.verifiedExternalAccounts.count == 2)
  }
  
  @Test func testUserUnverifiedExternalAccounts() {
    #expect(User.mock.unverifiedExternalAccounts.count == 1)
  }
  
}

@Suite(.serialized) struct UserSeralizedTests {
  
  init() {
    Container.shared.reset()
  }
  
  @Test func testUserUpdateRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me")
    let updatePasswordParams = User.UpdateParams(
      username: "new_username",
      firstName: "new_first",
      lastName: "new_last",
      primaryEmailAddressId: "1",
      primaryPhoneNumberId: "1",
      unsafeMetadata: "new_metadata"
    )
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler(requestCallback: { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["username"] == updatePasswordParams.username)
      #expect(request.urlEncodedFormBody["first_name"] == updatePasswordParams.firstName)
      #expect(request.urlEncodedFormBody["last_name"] == updatePasswordParams.lastName)
      #expect(request.urlEncodedFormBody["primary_email_address_id"] == updatePasswordParams.primaryEmailAddressId)
      #expect(request.urlEncodedFormBody["primary_phone_number_id"] == updatePasswordParams.primaryPhoneNumberId)
      #expect(request.urlEncodedFormBody["unsafe_metadata"] == updatePasswordParams.unsafeMetadata?.stringValue)
      requestHandled.setValue(true)
    })
    mock.register()
    try await User.mock.update(updatePasswordParams)
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreateEmailAddressRequest() async throws {
    let requestHandled = LockIsolated(false)
    let emailAddress = "user@email.com"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/email_addresses")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["email_address"] == emailAddress)
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.createEmailAddress(emailAddress)
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreatePhoneNumberRequest() async throws {
    let requestHandled = LockIsolated(false)
    let phoneNumber = "5555550100"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/phone_numbers")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["phone_number"] == phoneNumber)
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.createPhoneNumber(phoneNumber)
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreateExternalAccountOAuthRequest() async throws {
    let requestHandled = LockIsolated(false)
    let provider = OAuthProvider.google
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/external_accounts")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>.init(response: .mockUnverified, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["strategy"] == provider.strategy)
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.createExternalAccount(provider)
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreateExternalAccountIdTokenRequest() async throws {
    let requestHandled = LockIsolated(false)
    let token = "12345"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/external_accounts")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>.init(response: .mockUnverified, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody["token"] == token)
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.createExternalAccount(.apple, idToken: token)
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreatePasskeyRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/passkeys")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    
    // we don't have a real nonce/challenge, so this will throw
    await #expect(throws: Error.self, performing: {
      try await User.mock.createPasskey()
    })
    #expect(requestHandled.value)
  }
  
  @Test func testUserCreateTOTPRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/totp")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<TOTPResource>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.createTOTP()
    #expect(requestHandled.value)
  }
  
  @Test func testUserVerifyTOTPRequest() async throws {
    let requestHandled = LockIsolated(false)
    let code = "12345"
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/totp/attempt_verification")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<TOTPResource>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["code"] == code)
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.verifyTOTP(code: code)
    #expect(requestHandled.value)
  }
  
  @Test func testUserDisableTOTPRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/totp")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.disableTOTP()
    #expect(requestHandled.value)
  }
  
  @Test func testUserGetSessionsRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/sessions/active")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode([Session.mock, Session.mock])
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.getSessions()
    #expect(requestHandled.value)
  }
  
  @Test func testUserUpdatePasswordRequest() async throws {
    let requestHandled = LockIsolated(false)
    let params = User.UpdatePasswordParams(
      newPassword: "newPass",
      currentPassword: "currentPass",
      signOutOfOtherSessions: true
    )
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/change_password")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["new_password"] == params.newPassword)
      #expect(request.urlEncodedFormBody["current_password"] == params.currentPassword)
      #expect(request.urlEncodedFormBody["sign_out_of_other_sessions"] == String(describing: NSNumber(booleanLiteral: params.signOutOfOtherSessions)))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.updatePassword(params)
    #expect(requestHandled.value)
  }
  
  @Test func testUserSetProfileImageRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/profile_image")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.value(forHTTPHeaderField: "Content-Type")!.contains("multipart/form-data; boundary="))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.setProfileImage(Data())
    #expect(requestHandled.value)
  }
  
  @Test func testUserDeleteProfileImageRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/profile_image")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.deleteProfileImage()
    #expect(requestHandled.value)
  }
  
  @Test func testUserDeleteRequest() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/me")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await User.mock.delete()
    #expect(requestHandled.value)
  }
  
}

