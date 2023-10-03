//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct SignIn: Codable {
    public let status: String
    public let supportedIdentifiers: [String]
    public let identifier: String?
    public let supportedExternalAccounts: [String]
//    public let supportedFirstFactors: [SignInFactor]
//    public let supportedSecondFactors: [SignInFactor]
    public let firstFactorVerification: Verification
    public let secondFactorVerification: Verification
//    public let userData: UserData
    public let createdSessionId: String?
}
