//
//  SignIn+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension SignIn {
    
    // First SignInFactor
    
    @MainActor
    var currentFirstFactor: SignInFactor? {
        if let firstFactorVerification,
           firstFactorVerification.strategy != "passkey",
           let currentFirstFactor = supportedFirstFactors?.first(where: {
               $0.strategy == firstFactorVerification.strategy &&
               $0.safeIdentifier == identifier
           }) {
            return currentFirstFactor
        }
        
        if status == .needsFirstFactor, let enterpriseSSOFactor = supportedFirstFactors?.first(where: {
            $0.strategy == "enterprise_sso"
        }) {
            return enterpriseSSOFactor
        }
        
        return startingSignInFirstFactor
    }
    
    @MainActor
    private var startingSignInFirstFactor: SignInFactor? {
        guard let preferredStrategy = Clerk.shared.environment?.displayConfig.preferredSignInStrategy else { return nil }
        let firstFactors = alternativeFirstFactors(currentFactor: nil) // filters out reset strategies and oauth
        
        switch preferredStrategy {
            
        case .password:
            let sortedFactors = firstFactors.sorted { $0.sortOrderPasswordPreferred < $1.sortOrderPasswordPreferred }
            if let passwordFactor = sortedFactors.first(where: { $0.strategy == "password" }) {
                return passwordFactor
            }
            
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
            
        case .otp:
            let sortedFactors = firstFactors.sorted { $0.sortOrderOTPPreferred < $1.sortOrderOTPPreferred }
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
            
        case .unknown:
            return nil
        }
    }
    
    var firstFactorHasBeenPrepared: Bool {
        firstFactorVerification != nil
    }
    
    func alternativeFirstFactors(currentFactor: SignInFactor?) -> [SignInFactor] {
        // Remove the current factor, reset factors, oauth factors, enterprise SSO factors, saml factors, passkey factors
        let firstFactors = supportedFirstFactors?.filter { factor in
            factor != currentFactor &&
            factor.isResetFactor == false  &&
            !(factor.strategy).hasPrefix("oauth_") &&
            factor.strategy != "enterprise_sso" &&
            factor.strategy != "saml" &&
            factor.strategy != "passkey"
        }
        
        return firstFactors?.sorted(by: { $0.sortOrderPasswordPreferred < $1.sortOrderPasswordPreferred }) ?? []
    }
    
    func firstFactor(for strategy: String) -> SignInFactor? {
        supportedFirstFactors?.first(where: { $0.strategy == strategy })
    }
    
    var resetFactor: SignInFactor? {
        supportedFirstFactors?.first(where: {
            $0.isResetFactor
        })
    }
    
    // Second SignInFactor
    
    var currentSecondFactor: SignInFactor? {
        guard status == .needsSecondFactor else { return nil }
        
        if let secondFactorVerification,
           let currentSecondFactor = supportedSecondFactors?.first(where: {
               $0.strategy == secondFactorVerification.strategy
           })
        {
            return currentSecondFactor
        }
        
        return startingSignInSecondFactor
    }
    
    // The priority of second factors is: TOTP -> Phone code -> any other factor
    private var startingSignInSecondFactor: SignInFactor? {
        if let totp = supportedSecondFactors?.first(where: { $0.strategy == "totp" }) {
            return totp
        }
        
        if let phoneCode = supportedSecondFactors?.first(where: { $0.strategy == "phone_code" }) {
            return phoneCode
        }
        
        return supportedSecondFactors?.first
    }
    
    var secondFactorHasBeenPrepared: Bool {
        secondFactorVerification != nil
    }
    
    func alternativeSecondFactors(currentFactor: SignInFactor?) -> [SignInFactor] {
        supportedSecondFactors?.filter { $0 != currentFactor } ?? []
    }
    
    func secondFactor(for strategy: String) -> SignInFactor? {
        supportedSecondFactors?.first(where: {
            $0.strategy == strategy &&
            $0.safeIdentifier == identifier
        })
    }
    
    // Reset Password
    
    var resetPasswordStrategy: SignIn.PrepareFirstFactorStrategy? {
        guard let supportedFirstFactors else { return nil }
        
        if let resetPasswordEmailFactor = supportedFirstFactors.first(where: { factor in
            factor.strategy == "reset_password_email_code" &&
            factor.safeIdentifier == identifier
        }), let emailAddressId = resetPasswordEmailFactor.emailAddressId {
            return .resetPasswordEmailCode(emailAddressId: emailAddressId)
        }
        
        if let resetPasswordEmailFactor = supportedFirstFactors.first(where: { factor in
            factor.strategy == "reset_password_phone_code" &&
            factor.safeIdentifier == identifier
        }), let phoneNumberId = resetPasswordEmailFactor.phoneNumberId {
            return .resetPasswordPhoneCode(phoneNumberId: phoneNumberId)
        }
        
        return nil
    }
    
}
