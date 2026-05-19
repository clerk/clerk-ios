//
//  UserUpdateParams.swift
//  Clerk
//

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
      message: "Use User.updateMetadata(unsafeMetadata:) for partial updates (deep merge). Passing unsafeMetadata to update(_:) is deprecated and will be removed in a future major version."
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
      _unsafeMetadata = unsafeMetadata
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

    /// Backing storage for the deprecated ``unsafeMetadata`` surface. Used by the
    /// routing logic in ``User/update(_:)`` so internal reads do not trigger the
    /// deprecation warning attached to the public computed property.
    // swiftlint:disable:next identifier_name
    var _unsafeMetadata: JSON?

    /// Metadata that can be read and set from the Frontend API. One common use case
    /// for this attribute is to implement custom fields that will be attached to the
    /// User object.
    @available(
      *, deprecated,
      message: "Use User.updateMetadata(unsafeMetadata:) for partial updates (deep merge). Passing unsafeMetadata to update(_:) is deprecated and will be removed in a future major version."
    )
    public var unsafeMetadata: JSON? {
      get { _unsafeMetadata }
      set { _unsafeMetadata = newValue }
    }

    private enum CodingKeys: String, CodingKey {
      case username
      case firstName
      case lastName
      case primaryEmailAddressId
      case primaryPhoneNumberId
      // swiftlint:disable:next identifier_name
      case _unsafeMetadata = "unsafeMetadata"
    }
  }
}

extension User.UpdateParams {
  /// True when any field other than `unsafeMetadata` would appear in the
  /// encoded request body. Computed via the actual encoder, so new fields
  /// added to the struct are picked up automatically without updating this
  /// helper.
  var hasAnyField: Bool {
    var copy = self
    copy._unsafeMetadata = nil
    guard let encoded = try? JSON(encodable: copy),
          case let .object(obj) = encoded
    else { return false }
    return !obj.isEmpty
  }
}
