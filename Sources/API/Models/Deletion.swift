//
//  Deletion.swift
//
//
//  Created by Mike Pitre on 7/5/24.
//

import Foundation

public struct Deletion: Decodable, Sendable {
    let id: String?
    let object: String?
    let deleted: Bool?
}
