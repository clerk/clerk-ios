//
//  UserProfileEmailSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct UserProfileEmailSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var addEmailAddressStep: UserProfileAddEmailView.Step?
    @State private var confirmDeleteEmailAddress: EmailAddress?
    
    @State private var deleteSheetHeight: CGFloat = .zero
    @Namespace private var namespace
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var emailAddresses: [EmailAddress] {
        (user?.emailAddresses ?? []).sorted { lhs, rhs in
            return lhs.isPrimary
        }
    }
    
    @ViewBuilder
    private func primaryCallout(emailAddress: EmailAddress) -> some View {
        if emailAddress.isPrimary {
            VStack(alignment: .leading, spacing: 6) {
                Text("Primary email address")
                    .font(.footnote)
                Text("This email address is the primary email address")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if emailAddress.verification?.status == .verified {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set as primary email address")
                    .font(.footnote)
                Text("Set this email address as the primary to receive communications regarding your account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AsyncButton {
                    await setAsPrimary(emailAddress: emailAddress)
                } label: {
                    Text("Set as primary")
                        .font(.footnote.weight(.medium))
                }
                .tint(clerkTheme.colors.primary)
            }
        }
    }
    
    private func setAsPrimary(emailAddress: EmailAddress) async {
        do {
            try await emailAddress.setAsPrimary()
        } catch {
            dump(error)
        }
    }
    
    @ViewBuilder
    private func unverifiedCallout(emailAddress: EmailAddress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Verify email address")
                .font(.footnote)
            Text("Complete verification to access all features with this email address")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: {
                addEmailAddressStep = .code(emailAddress: emailAddress)
            }, label: {
                Text("Verify email address")
                    .font(.footnote.weight(.medium))
            })
            .tint(clerkTheme.colors.primary)
        }
    }
    
    @ViewBuilder
    private func removeCallout(emailAddress: EmailAddress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remove")
                .font(.footnote)
            Text("Delete this email address and remove it from your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Remove email address", role: .destructive) {
                confirmDeleteEmailAddress = emailAddress
            }
            .font(.footnote.weight(.medium))
            .popover(item: $confirmDeleteEmailAddress) { emailAddress in
                UserProfileRemoveResourceView(resource: .email(emailAddress))
                    .padding(.top)
                    .readSize { deleteSheetHeight = $0.height }
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.height(deleteSheetHeight)])
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Email addresses")
            VStack(alignment: .leading, spacing: 24) {
                ForEach(emailAddresses) { emailAddress in
                    AccordionView {
                        HStack {
                            Text(verbatim: emailAddress.emailAddress)
                                .font(.footnote)
                            
                            if emailAddress.isPrimary {
                                CapsuleTag(text: "Primary")
                                    .matchedGeometryEffect(id: "primaryCapsule", in: namespace)
                            }
                            
                            if emailAddress.verification?.status != .verified {
                                CapsuleTag(text: "Unverified", style: .warning)
                            }
                        }
                    } expandedContent: {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            primaryCallout(emailAddress: emailAddress)
                                .matchedGeometryEffect(id: "\(emailAddress.id)", in: namespace)
                            
                            if emailAddress.verification?.status != .verified {
                                unverifiedCallout(emailAddress: emailAddress)
                            }
                            
                            removeCallout(emailAddress: emailAddress)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    }
                }
                
                Button(action: {
                    addEmailAddressStep = .add
                }, label: {
                    Text("+ Add an email address")
                })
                .font(.footnote.weight(.medium))
                .tint(clerkTheme.colors.primary)
                .padding(.leading, 8)
            }
            .animation(.snappy, value: user)
        }
        .sheet(item: $addEmailAddressStep) { step in
            UserProfileAddEmailView(initialStep: step)
        }
    }
}

#Preview {
    _ = Container.shared.clerk.register { Clerk.mock }
    return UserProfileEmailSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
