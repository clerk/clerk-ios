//
//  UserData.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

import Foundation

public struct UserData: Codable {
    public var firstName: String?
    public var lastName: String?
    public var imageUrl: String = ""
    var hasImage: Bool = false
}
