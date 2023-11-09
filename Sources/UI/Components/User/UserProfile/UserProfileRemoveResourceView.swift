//
//  UserProfileRemoveResource.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

extension UserProfileRemoveResourceView {
    enum Resource {
        case email(EmailAddress)
        case phoneNumber(PhoneNumber)
        case externalAccount(ExternalAccount)
        
        var title: String {
            switch self {
            case .email:
                return "Remove email address"
            case .phoneNumber:
                return "Remove phone number"
            case .externalAccount:
                return "Remove connected account"
            }
        }
        
        var messageLine1: String {
            switch self {
            case .email(let emailAddress):
                return "\(emailAddress.emailAddress) will be removed from this account."
            case .phoneNumber(let phoneNumber):
                return "\(phoneNumber.flag ?? "") \(phoneNumber.formatted(.international)) will be removed from this account."
            case .externalAccount(let externalAccount):
                return "\(externalAccount.externalProvider?.data.name ?? "This provider") will be removed from this account."
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
            }
        }
        
        func deleteAction() async throws {
            switch self {
            case .email(let emailAddress):
                try await emailAddress.delete()
            case .phoneNumber(let phoneNumber):
                try await phoneNumber.delete()
            case .externalAccount(let externalAccount):
                try await externalAccount.delete()
            }
        }
    }
}

struct UserProfileRemoveResourceView: View {
    @Environment(\.dismiss) private var dismiss

    let resource: Resource
    
    var body: some View {
        RemoveResourceView(
            title: resource.title,
            messageLine1: resource.messageLine1,
            messageLine2: resource.messageLine2
        )
        .onDelete {
            do {
                try await resource.deleteAction()
                dismiss()
            } catch {
                dump(error)
            }
        }
    }
}

#Preview {
    ScrollView {
        UserProfileRemoveResourceView(resource: .email(.init(id: "123", emailAddress: "ClerkUser@clerk.dev")))
        UserProfileRemoveResourceView(resource: .phoneNumber(.init(id: "123", phoneNumber: "+12015550123")))
    }
}

#endif
