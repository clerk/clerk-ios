//
//  UserProfilePhoneNumberSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct UserProfilePhoneNumberSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    private let phoneNumberKit = Container.shared.phoneNumberKit
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var phoneNumbers: [PhoneNumber] {
        user?.phoneNumbers ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Phone numbers")
            ForEach(phoneNumbers) { phoneNumber in
                AccordionView {
                    HStack(spacing: 8) {
                        if let flag = phoneNumber.flag {
                            Text(flag)
                        }
                        Text(verbatim: phoneNumber.formatted(.national))
                    }
                    .font(.footnote.weight(.medium))
                } expandedContent: {
                    VStack(alignment: .leading) {
                        Text("Remove")
                            .font(.footnote.weight(.medium))
                        Text("Delete this phone number and remove it from your account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Remove phone number", role: .destructive) {
                            // delete email
                        }
                        .font(.footnote)
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                }
            }
            
            Button(action: {
                // add phone number
            }, label: {
                Text("+ Add a phone number")
            })
            .font(.footnote.weight(.medium))
            .tint(clerkTheme.colors.primary)
            .padding(.vertical, 4)
            .padding(.leading, 8)
        }
    }
}

#Preview {
    UserProfilePhoneNumberSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
