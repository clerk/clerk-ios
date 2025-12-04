//
//  SignInUserData.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

public extension SignIn {
  /// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
  struct UserData: Codable, Sendable, Equatable {
    /// The user's first name.
    public let firstName: String?

    /// The user's last name.
    public let lastName: String?

    /// Holds the default avatar or user's uploaded profile image.
    public let imageUrl: String?

    /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
    public let hasImage: Bool?

    public init(
      firstName: String? = nil,
      lastName: String? = nil,
      imageUrl: String? = nil,
      hasImage: Bool? = nil
    ) {
      self.firstName = firstName
      self.lastName = lastName
      self.imageUrl = imageUrl
      self.hasImage = hasImage
    }
  }
}
