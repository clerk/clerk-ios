//
//  PublicUserData.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 2/12/25.
//

import Foundation

/// Represents publicly available information about a user.
public struct PublicUserData: Codable, Sendable, Equatable {
  /// The user's first name.
  public let firstName: String?

  /// The user's last name.
  public let lastName: String?

  /// Holds the default avatar or user's uploaded profile image.
  /// Compatible with Clerk's Image Optimization.
  public let imageUrl: String

  /// A boolean indicating whether the user has uploaded an image or one was copied from OAuth.
  /// Returns `false` if Clerk is displaying a default avatar for the user.
  public let hasImage: Bool

  /// The user's identifier.
  public let identifier: String

  /// The user's ID.
  public let userId: String?

  public init(
    firstName: String? = nil,
    lastName: String? = nil,
    imageUrl: String,
    hasImage: Bool,
    identifier: String,
    userId: String? = nil
  ) {
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.hasImage = hasImage
    self.identifier = identifier
    self.userId = userId
  }
}
