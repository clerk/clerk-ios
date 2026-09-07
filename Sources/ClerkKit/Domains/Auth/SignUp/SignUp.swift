//
//  SignUp.swift
//

import AuthenticationServices
import Foundation

/// The `SignUp` object holds the state of the current sign-up and provides helper methods to
/// manage verification and session creation.
public struct SignUp: Codable, Sendable, Equatable {
  /// The unique identifier of the current sign-up.
  public var id: String

  /// The status of the current sign-up.
  ///
  /// See ``SignUp/Status-swift.enum`` for supported values.
  public var status: Status

  /// An array of all the required fields that need to be supplied and verified in order for this sign-up to be marked as complete and converted into a user.
  public var requiredFields: [Field]

  /// An array of all the fields that can be supplied to the sign-up, but their absence does not prevent the sign-up from being marked as complete.
  public var optionalFields: [Field]

  /// An array of all the fields whose values are not supplied yet but they are mandatory in order for a sign-up to be marked as complete.
  public var missingFields: [Field]

  /// An array of all the fields whose values have been supplied, but they need additional verification in order for them to be accepted.
  ///
  /// Examples of such fields are `email_address` and `phone_number`.
  public var unverifiedFields: [Field]

  /// An object that contains information about all the verifications that are in-flight.
  public var verifications: [String: Verification?]

  /// The username supplied to the current sign-up. Only supported if username is enabled in the instance settings.
  public var username: String?

  /// The email address supplied to the current sign-up. Only supported if email address is enabled in the instance settings.
  public var emailAddress: String?

  /// The user's phone number in E.164 format. Only supported if phone number is enabled in the instance settings.
  public var phoneNumber: String?

  /// The Web3 wallet address, made up of 0x + 40 hexadecimal characters. Only supported if Web3 authentication is enabled in the instance settings.
  public var web3Wallet: String?

  /// The value of this attribute is true if a password was supplied to the current sign-up. Only supported if password is enabled in the instance settings.
  public var passwordEnabled: Bool

  /// The first name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
  public var firstName: String?

  /// The last name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
  public var lastName: String?

  /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
  public var unsafeMetadata: JSON?

  /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
  public var createdSessionId: String?

  /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
  public var createdUserId: String?

  /// The date when the sign-up was abandoned by the user.
  public var abandonAt: Date

  public init(
    id: String,
    status: SignUp.Status,
    requiredFields: [Field],
    optionalFields: [Field],
    missingFields: [Field],
    unverifiedFields: [Field],
    verifications: [String: Verification?],
    username: String? = nil,
    emailAddress: String? = nil,
    phoneNumber: String? = nil,
    web3Wallet: String? = nil,
    passwordEnabled: Bool,
    firstName: String? = nil,
    lastName: String? = nil,
    unsafeMetadata: JSON? = nil,
    createdSessionId: String? = nil,
    createdUserId: String? = nil,
    abandonAt: Date
  ) {
    self.id = id
    self.status = status
    self.requiredFields = requiredFields
    self.optionalFields = optionalFields
    self.missingFields = missingFields
    self.unverifiedFields = unverifiedFields
    self.verifications = verifications
    self.username = username
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.web3Wallet = web3Wallet
    self.passwordEnabled = passwordEnabled
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.createdSessionId = createdSessionId
    self.createdUserId = createdUserId
    self.abandonAt = abandonAt
  }
}

extension SignUp {
  // MARK: - Internal Helpers

  var needsTransferToSignIn: Bool {
    verifications.contains(where: { $0.key == "external_account" && $0.value?.status == .transferable })
  }

  @discardableResult @MainActor
  func handleRedirectCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignUp = try await reload(rotatingTokenNonce: nonce)
      if let verification = updatedSignUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
      return .signUp(updatedSignUp)
    } else {
      // transfer flow
      let signUp = try await reload()
      let result = try await signUp.handleTransferFlow()
      switch result {
      case .signIn(let signIn):
        if let error = signIn.firstFactorVerification?.error {
          throw error
        }
      case .signUp(let signUp):
        if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
           let error = verification.error
        {
          throw error
        }
      }
      return result
    }
  }
}
