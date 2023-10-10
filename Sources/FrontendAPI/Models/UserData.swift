//
//  UserData.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

import Foundation

struct UserData: Decodable {
    var firstName: String?
    var lastName: String?
    var imageUrl: String = ""
    var hasImage: Bool = false
}
