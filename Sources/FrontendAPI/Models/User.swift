//
//  User.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

import Foundation

public struct User: Decodable {
    public let id: String
    public let firstName: String?
    public let lastName: String?
    public let username: String?
    public let imageUrl: String
}
