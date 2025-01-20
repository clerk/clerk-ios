//
//  ExternalAccount+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension ExternalAccount {
    
    var oauthProvider: OAuthProvider {
        // provider on an external account is the strategy value
        .init(strategy: provider)
    }
    
    /// Username if available, otherwise email address
    var displayName: String {
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        } else {
            return emailAddress
        }
    }
    
    var fullName: String? {
        let fullName = [firstName, lastName]
            .compactMap { $0 }
            .filter({ !$0.isEmpty })
            .joined(separator: " ")
        
        return fullName.isEmpty ? nil : fullName
    }
    
}

extension ExternalAccount: Comparable {
    public static func < (lhs: ExternalAccount, rhs: ExternalAccount) -> Bool {
        if lhs.verification?.status != rhs.verification?.status  {
            return lhs.verification?.status == .verified
        } else {
            return lhs.oauthProvider.strategy < rhs.oauthProvider.strategy
        }
    }
}
