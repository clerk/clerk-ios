//
//  SignUp+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation

extension SignUp {
    
    /// Returns the next strategy to use to verify an attribute that needs to verified at sign up
    @MainActor
    var nextStrategyToVerify: String? {
        
        if let externalVerification = verifications.first(where: { $0.value?.externalVerificationRedirectUrl != nil && $0.value?.status == .unverified }) {
            return externalVerification.value?.strategy
        } else {
            guard let attributesToVerify = Clerk.shared.environment?.userSettings.attributesToVerifyAtSignUp else { return nil }

            if unverifiedFields.contains(where: { $0 == "email_address" }) {
                return attributesToVerify.first(where: { $0.key == "email_address" })?.value.verifications?.first
                
            } else if unverifiedFields.contains(where: { $0 == "phone_number" }) {
                return attributesToVerify.first(where: { $0.key == "phone_number" })?.value.verifications?.first
                
            } else {
                return nil
            }
        }
    }
    
}
