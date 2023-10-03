//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct SignUp: Codable {
    public let status: String?
    public let requiredFields: [String]
    public let optionalFields: [String]
    public let missingFields: [String]
    public let unverifiedFields: [String]
//    public let verifications: SignUpVerifications
    public let username: String?
    public let emailAddress: String?
    public let phoneNumber: String?
    public let web3Wallet: String?
    public let hasPassword: Bool
    public let firstName: String?
    public let lastName: String?
    public let unsafeMetaData: JSON
    public let createdSessionId: String?
    public let createdUserId: String?
    public let abandonAt: Int?
}
