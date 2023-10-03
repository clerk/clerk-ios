//
//  PublicUserData.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct PublicUserData: Codable {
    public let firstName: String?
    public let lastName: String?
    public let imageUrl: String
    public let identifier: String
    public let userId: String?
}
