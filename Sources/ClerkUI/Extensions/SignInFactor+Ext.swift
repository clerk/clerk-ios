//
//  SignInFactor+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension SignInFactor {
    
    var isResetFactor: Bool {
        ["reset_password_email_code", "reset_password_phone_code"].contains(strategy)
    }
    
    var prepareFirstFactorStrategy: SignIn.PrepareFirstFactorStrategy? {
        switch strategy {
        case "phone_code":
            return .phoneCode(phoneNumberId: phoneNumberId)
        case "email_code":
            return .emailCode(emailAddressId: emailAddressId)
        case "reset_password_phone_code":
            return .resetPasswordPhoneCode(phoneNumberId: phoneNumberId)
        case "reset_password_email_code":
            return .resetPasswordEmailCode(emailAddressId: emailAddressId)
        case "passkey":
            return .passkey
        case "enterprise_sso":
            return .enterpriseSSO
        default:
            return nil
        }
    }
    
    var prepareSecondFactorStrategy: SignIn.PrepareSecondFactorStrategy? {
        switch strategy {
        case "phone_code":
            return .phoneCode
        default:
            return nil
        }
    }
    
    var actionText: String? {
        switch strategy {
        case "phone_code":
            guard let safeIdentifier else { return nil }
            return "Send SMS code to \(safeIdentifier)"
        case "email_code":
            guard let safeIdentifier else { return nil }
            return "Email code to \(safeIdentifier)"
        case "passkey":
            return "Sign in with your passkey"
        case "password":
            return "Sign in with your password"
        case "totp":
            return "Use your authenticator app"
        case "backup_code":
            return "Use a backup code"
        default:
            return nil
        }
    }
    
    var sortOrderPasswordPreferred: Int {
        let options: [String] = [
            "passkey",
            "password",
            "email_code",
            "phone_code"
        ]
        
        return options.firstIndex(of: strategy) ?? 100
    }
    
    var sortOrderOTPPreferred: Int {
        let options: [String] = [
            "passkey",
            "email_code",
            "phone_code",
            "password",
        ]
        
        return options.firstIndex(of: strategy) ?? 100
    }
    
}
