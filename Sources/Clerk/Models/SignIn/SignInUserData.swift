//
//  UserData.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//


/// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
public struct UserData: Codable, Sendable, Equatable, Hashable {
    public let firstName: String?
    public let lastName: String?
    public let imageUrl: String?
    public let hasImage: Bool?
}
