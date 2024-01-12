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
    
    @Namespace private var namespace
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var emailAddresses: [EmailAddress] {
        (user?.emailAddresses ?? []).sorted { lhs, rhs in
            if let user {
                return lhs.isPrimary(for: user)
            } else {
                return false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Email addresses")
                .frame(minHeight: 32)
                .font(.footnote.weight(.medium))
            
            if let user {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(emailAddresses) { emailAddress in
                        EmailAddressRowView(
                            emailAddress: emailAddress,
                            user: user,
                            namespace: namespace,
                            addEmailAddressStep: $addEmailAddressStep
                        )
                    }
                    
                    Button(action: {
                        addEmailAddressStep = .add
                    }, label: {
                        Text("+ Add an email address")
                            .font(.caption.weight(.medium))
                            .frame(minHeight: 32)
                            .tint(clerkTheme.colors.textPrimary)
                    })
                }
                .padding(.leading, 12)
            }
            
            Divider()
        }
        .sheet(item: $addEmailAddressStep) { step in
            UserProfileAddEmailView(initialStep: step)
        }
    }
    
    private struct EmailAddressRowView: View {
        let emailAddress: EmailAddress
        let user: User
        let namespace: Namespace.ID
        @Binding var addEmailAddressStep: UserProfileAddEmailView.Step?
        @State private var confirmationSheetIsPresented = false
        @State private var errorWrapper: ErrorWrapper?
        @Environment(\.clerkTheme) private var clerkTheme
        
        private var removeResource: RemoveResource { .email(emailAddress) }
        
        var body: some View {
            HStack {
                Text(verbatim: emailAddress.emailAddress)
                    .font(.footnote)
                
                if emailAddress.isPrimary(for: user) {
                    CapsuleTag(text: "Primary")
                        .matchedGeometryEffect(id: "primaryCapsule", in: namespace)
                }
                
                if emailAddress.verification?.status != .verified {
                    CapsuleTag(text: "Unverified", style: .warning)
                }
                
                Spacer()
                
                Menu {
                    if emailAddress.verification?.status == .verified && !emailAddress.isPrimary(for: user) {
                        setAsPrimaryButton
                    }
                    
                    if emailAddress.verification?.status != .verified {
                        verifyEmailButton
                    }
                    
                    removeEmailButton
                } label: {
                    MoreActionsView()
                }
                .tint(.primary)
            }
            .confirmationDialog(
                Text(removeResource.messageLine1),
                isPresented: $confirmationSheetIsPresented,
                titleVisibility: .visible
            ) {
                AsyncButton(role: .destructive) {
                    do {
                        try await removeResource.deleteAction()
                    } catch {
                        dump(error)
                    }
                } label: {
                    Text(removeResource.title)
                }
            } message: {
                Text(removeResource.messageLine2)
            }
        }
        
        @ViewBuilder
        private var setAsPrimaryButton: some View {
            AsyncButton {
                await setAsPrimary(emailAddress: emailAddress)
            } label: {
                Text("Set as primary")
            }
        }
        
        private func setAsPrimary(emailAddress: EmailAddress) async {
            do {
                try await emailAddress.setAsPrimary()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        
        @ViewBuilder
        private var verifyEmailButton: some View {
            Button("Verify email") {
                addEmailAddressStep = .code(emailAddress: emailAddress)
            }
        }
        
        @ViewBuilder
        private var removeEmailButton: some View {
            Button("Remove email", role: .destructive) {
                confirmationSheetIsPresented = true
            }
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
