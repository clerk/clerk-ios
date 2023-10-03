//
//  EmailAddress.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct EmailAddress: Codable {
    public let id: String
    public let emailAddress: String
    public let verification: Verification
    public let linkedTo: [LinkedTo]
}
