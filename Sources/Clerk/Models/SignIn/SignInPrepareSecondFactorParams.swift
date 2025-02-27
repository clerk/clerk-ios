//
//  SignInPrepareSecondFactor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {
    
    /// A parameter object for preparing the second factor verification.
    struct PrepareSecondFactorParams: Encodable {
        /// The strategy used for second factor verification..
        let strategy: String
    }
    
    /// A strategy for preparing the second factor verification process.
  public enum PrepareSecondFactorStrategy: Sendable {
        
        /// phoneCode: The user will receive a one-time authentication code via SMS. At least one phone number should be on file for the user.
        case phoneCode
        
        var params: PrepareSecondFactorParams {
            switch self {
            case .phoneCode:
                return .init(strategy: "phone_code")
            }
        }
    }
}
