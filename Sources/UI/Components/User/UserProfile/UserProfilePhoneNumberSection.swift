//
//  UserProfilePhoneNumberSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Factory

struct UserProfilePhoneNumberSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var addPhoneNumberStep: UserProfileAddPhoneNumberView.Step?
    @State private var confirmDeletePhoneNumber: PhoneNumber?
    
    @Namespace private var namespace
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var phoneNumbers: [PhoneNumber] {
        (user?.phoneNumbers ?? []).sorted { lhs, rhs in
            if let user {
                return lhs.isPrimary(for: user)
            } else {
                return false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Phone numbers")
                .font(.footnote.weight(.medium))
                .frame(minHeight: 32)
            
            if let user {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(phoneNumbers) { phoneNumber in
                        PhoneNumberRow(
                            phoneNumber: phoneNumber,
                            user: user,
                            namespace: namespace,
                            addPhoneNumberStep: $addPhoneNumberStep
                        )
                    }
                    
                    Button(action: {
                        addPhoneNumberStep = .add
                    }, label: {
                        Text("+ Add a phone number")
                            .font(.caption.weight(.medium))
                            .frame(minHeight: 32)
                            .tint(clerkTheme.colors.textPrimary)
                    })
                    .sheet(item: $addPhoneNumberStep) { step in
                        UserProfileAddPhoneNumberView(initialStep: step)
                    }
                }
                .padding(.leading, 12)
            }
            
            Divider()
        }
        .animation(.snappy, value: user)
    }
    
    private struct PhoneNumberRow: View {
        let phoneNumber: PhoneNumber
        let user: User
        var namespace: Namespace.ID
        @Binding var addPhoneNumberStep: UserProfileAddPhoneNumberView.Step?
        @State private var confirmationSheetIsPresented = false
        @State private var errorWrapper: ErrorWrapper?
        @Environment(\.clerkTheme) private var clerkTheme
        
        private var removeResource: RemoveResource { .phoneNumber(phoneNumber) }
        
        var body: some View {
            HStack(spacing: 8) {
                Text(verbatim: phoneNumber.formatted(.international))
                    .font(.footnote)
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
                
                if phoneNumber.isPrimary(for: user) {
                    CapsuleTag(text: "Primary")
                        .matchedGeometryEffect(id: "primaryCapsule", in: namespace)
                }
                
                if phoneNumber.verification?.status != .verified {
                    CapsuleTag(text: "Unverified", style: .warning)
                }
                
                Spacer()
                
                Menu {
                    if phoneNumber.verification?.status == .verified && !phoneNumber.isPrimary(for: user) {
                        setAsPrimaryButton
                    }
                    
                    if phoneNumber.verification?.status != .verified {
                        Button("Verify phone number") {
                            addPhoneNumberStep = .code(phoneNumber: phoneNumber)
                        }
                    }
                    
                    Button("Remove phone number", role: .destructive) {
                        confirmationSheetIsPresented = true
                    }
                } label: {
                    MoreActionsView()
                }
                .tint(clerkTheme.colors.textPrimary)
            }
            .clerkErrorPresenting($errorWrapper)
        }
        
        @ViewBuilder
        private var setAsPrimaryButton: some View {
            AsyncButton {
                do {
                    try await phoneNumber.setAsPrimary()
                } catch {
                    errorWrapper = ErrorWrapper(error: error)
                    dump(error)
                }
            } label: {
                Text("Set as primary")
            }
        }
    }
}

#Preview {
    _ = Container.shared.clerk.register { Clerk.mock }
    return UserProfilePhoneNumberSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
