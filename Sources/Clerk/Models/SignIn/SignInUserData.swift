//
//  UserData.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

extension SignIn {
    
    /// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
    public struct UserData: Codable, Sendable, Equatable, Hashable {
        
        /// The user's first name.
        public let firstName: String?
        
        /// The user's last name.
        public let lastName: String?
        
        /// Holds the default avatar or user's uploaded profile image.
        public let imageUrl: String?
        
        /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
        public let hasImage: Bool?
    }
    
}
