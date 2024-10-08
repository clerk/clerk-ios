//
//  RemoveResource.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

import Foundation

enum RemoveResource {
    case email(EmailAddress)
    case phoneNumber(PhoneNumber)
    case externalAccount(ExternalAccount)
    case passkey(Passkey)
    
    var title: String {
        switch self {
        case .email:
            return "Remove email address"
        case .phoneNumber:
            return "Remove phone number"
        case .externalAccount:
            return "Remove connected account"
        case .passkey:
            return "Remove passkey"
        }
    }
    
    @MainActor
    var messageLine1: String {
        switch self {
        case .email(let emailAddress):
            return "\(emailAddress.emailAddress) will be removed from this account."
        case .phoneNumber(let phoneNumber):
            return "\(phoneNumber.formatted(.national)) will be removed from this account."
        case .externalAccount(let externalAccount):
            return "\(externalAccount.oauthProvider.name) will be removed from this account."
        case .passkey(let passkey):
            return "\(passkey.name) will be removed from this account."
        }
    }
    
    var messageLine2: String {
        switch self {
        case .email:
            return "You will no longer be able to sign in using this email address."
        case .phoneNumber:
            return "You will no longer be able to sign in using this phone number."
        case .externalAccount:
            return "You will no longer be able to use this connected account and any dependent features will no longer work."
        case .passkey:
            return "You will no longer be able to sign in using this passkey."
        }
    }
    
    func deleteAction() async throws {
        switch self {
        case .email(let emailAddress):
            try await emailAddress.destroy()
        case .phoneNumber(let phoneNumber):
            try await phoneNumber.destroy()
        case .externalAccount(let externalAccount):
            try await externalAccount.destroy()
        case .passkey(let passkey):
            try await passkey.destroy()
        }
    }
}
