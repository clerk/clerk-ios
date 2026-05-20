//
//  UserUpdateParams.swift
//  Clerk
//

import Foundation

extension User {
  public struct UpdateParams: Encodable, Sendable {
    public init(
      username: String? = nil,
      firstName: String? = nil,
      lastName: String? = nil,
      primaryEmailAddressId: String? = nil,
      primaryPhoneNumberId: String? = nil
    ) {
      self.username = username
      self.firstName = firstName
      self.lastName = lastName
      self.primaryEmailAddressId = primaryEmailAddressId
      self.primaryPhoneNumberId = primaryPhoneNumberId
    }

    @available(
      *, deprecated,
      message: "Use User.updateMetadata(unsafeMetadata:) for metadata updates. Passing unsafeMetadata to update(_:) will be removed in a future major version."
    )
    public init(
      username: String? = nil,
      firstName: String? = nil,
      lastName: String? = nil,
      primaryEmailAddressId: String? = nil,
      primaryPhoneNumberId: String? = nil,
      unsafeMetadata: JSON?
    ) {
      self.username = username
      self.firstName = firstName
      self.lastName = lastName
      self.primaryEmailAddressId = primaryEmailAddressId
      self.primaryPhoneNumberId = primaryPhoneNumberId
      deprecatedUnsafeMetadata = unsafeMetadata
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

    var deprecatedUnsafeMetadata: JSON?

    /// Metadata that can be read and set from the Frontend API. One common use case
    /// for this attribute is to implement custom fields that will be attached to the
    /// User object.
    @available(
      *, deprecated,
      message: "Use User.updateMetadata(unsafeMetadata:) for metadata updates. Passing unsafeMetadata to update(_:) will be removed in a future major version."
    )
    public var unsafeMetadata: JSON? {
      get { deprecatedUnsafeMetadata }
      set { deprecatedUnsafeMetadata = newValue }
    }

    private enum CodingKeys: String, CodingKey {
      case username
      case firstName
      case lastName
      case primaryEmailAddressId
      case primaryPhoneNumberId
      case deprecatedUnsafeMetadata = "unsafeMetadata"
    }
  }

  public struct UpdateMetadataParams: Encodable, Sendable {
    public init(unsafeMetadata: JSON) {
      self.unsafeMetadata = unsafeMetadata
    }

    /// The unsafe metadata patch to merge into the current value.
    public var unsafeMetadata: JSON
  }
}

extension User.UpdateParams {
  var hasAnyField: Bool {
    var copy = self
    copy.deprecatedUnsafeMetadata = nil

    guard let data = try? JSONEncoder.clerkEncoder.encode(copy),
          let encoded = try? JSONDecoder.clerkDecoder.decode(JSON.self, from: data),
          case let .object(object) = encoded
    else { return false }

    return !object.isEmpty
  }

  var withoutUnsafeMetadata: Self {
    var copy = self
    copy.deprecatedUnsafeMetadata = nil
    return copy
  }
}
