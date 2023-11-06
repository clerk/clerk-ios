//
//  UserProfileEmailSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileEmailSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var addEmailAddressIsPresented: Bool = false
    @State private var confirmDeleteEmailAddress: EmailAddress?
    
    @State private var deleteSheetHeight: CGFloat = .zero
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var emailAddresses: [EmailAddress] {
        user?.emailAddresses ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Email addresses")
            ForEach(emailAddresses) { emailAddress in
                AccordionView {
                    Text(verbatim: emailAddress.emailAddress)
                        .font(.footnote.weight(.medium))
                } expandedContent: {
                    VStack(alignment: .leading) {
                        Text("Remove")
                            .font(.footnote.weight(.medium))
                        Text("Delete this email address and remove it from your account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Remove email address", role: .destructive) {
                            confirmDeleteEmailAddress = emailAddress
                        }
                        .font(.footnote)
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                }
                .sheet(item: $confirmDeleteEmailAddress) { emailAddress in
                    UserProfileDeleteEmailView(emailAddress: emailAddress)
                        .padding(.top)
                        .readSize { deleteSheetHeight = $0.height }
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.height(deleteSheetHeight)])
                }
            }
            
            Button(action: {
                addEmailAddressIsPresented = true
            }, label: {
                Text("+ Add an email address")
            })
            .font(.footnote.weight(.medium))
            .tint(clerkTheme.colors.primary)
            .padding(.vertical, 4)
            .padding(.leading, 8)
        }
        .sheet(isPresented: $addEmailAddressIsPresented) {
            UserProfileAddEmailView()
        }
    }
}

#Preview {
    UserProfileEmailSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
