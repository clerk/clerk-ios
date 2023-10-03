//
//  PhoneNumber.swift
//  
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct PhoneNumber: Codable {
    public let id: String
    public let phoneNumber: String
    public let reservedForSecondFactor: Bool
    public let defaultSecondFactor: Bool
    public let verification: Verification
    public let linkedTo: [LinkedTo]
    public let backupCodes: [String]?
}
