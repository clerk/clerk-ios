//
//  UserUpdateParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

extension User {

  public struct UpdateParams: Encodable, Sendable {

    public init(
      username: String? = nil,
      firstName: String? = nil,
      lastName: String? = nil,
      primaryEmailAddressId: String? = nil,
      primaryPhoneNumberId: String? = nil,
      unsafeMetadata: JSON? = nil
    ) {
      self.username = username
      self.firstName = firstName
      self.lastName = lastName
      self.primaryEmailAddressId = primaryEmailAddressId
      self.primaryPhoneNumberId = primaryPhoneNumberId
      self.unsafeMetadata = unsafeMetadata
    }

    /// The user's username.
    public var username: String?

    /// The user's first name.
    public var firstName: String?

    /// The user's last name.
    public var lastName: String?

    /// The unique identifier for the EmailAddress that the user has set as primary.
    public var primaryEmailAddressId: String?

    /// The unique identifier for the PhoneNumber that the user has set as primary.
    public var primaryPhoneNumberId: String?

    /**
     Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
     Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
     */
    public var unsafeMetadata: JSON?
  }

}
