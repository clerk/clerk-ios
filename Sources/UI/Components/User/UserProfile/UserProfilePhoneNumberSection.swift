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
    
    @State private var addPhoneNumberStep: UserProfileAddPhoneNumberView.Step?
    @State private var confirmDeletePhoneNumber: PhoneNumber?
    @State private var errorWrapper: ErrorWrapper?
    
    @Namespace private var namespace
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var phoneNumbers: [PhoneNumber] {
        (user?.phoneNumbers ?? []).sorted { lhs, rhs in
            return lhs.isPrimary
        }
    }
    
    @ViewBuilder
    private func primaryCallout(phoneNumber: PhoneNumber) -> some View {
        if phoneNumber.isPrimary {
            VStack(alignment: .leading, spacing: 6) {
                Text("Primary phone number")
                    .font(.footnote)
                Text("This phone number is the primary phone number")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if phoneNumber.verification?.status == .verified {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set as primary phone number")
                    .font(.footnote)
                Text("Set this phone number as the primary to receive communications regarding your account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AsyncButton {
                    await setAsPrimary(phoneNumber: phoneNumber)
                } label: {
                    Text("Set as primary")
                        .font(.footnote.weight(.medium))
                }
                .tint(clerkTheme.colors.textPrimary)
            }
        }
    }
    
    private func setAsPrimary(phoneNumber: PhoneNumber) async {
        do {
            try await phoneNumber.setAsPrimary()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    @ViewBuilder
    private func unverifiedCallout(phoneNumber: PhoneNumber) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Verify phone number")
                .font(.footnote)
            Text("Complete verification to access all features with this phone number")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: {
                addPhoneNumberStep = .code(phoneNumber: phoneNumber)
            }, label: {
                Text("Verify phone number")
                    .font(.footnote.weight(.medium))
            })
            .tint(clerkTheme.colors.textPrimary)
        }
    }
    
    private struct RemovePhoneNumberView: View {
        let phoneNumber: PhoneNumber
        @State private var confirmationSheetIsPresented = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Remove")
                    .font(.footnote)
                Text("Delete this phone number and remove it from your account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Remove phone number", role: .destructive) {
                    confirmationSheetIsPresented = true
                }
                .font(.footnote.weight(.medium))
                .popover(isPresented: $confirmationSheetIsPresented) {
                    UserProfileRemoveResourceView(resource: .phoneNumber(phoneNumber))
                        .padding(.top)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.height(250)])
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Phone numbers")
            VStack(alignment: .leading, spacing: 24) {
                ForEach(phoneNumbers) { phoneNumber in
                    AccordionView {
                        HStack(spacing: 8) {
                            if let flag = phoneNumber.flag {
                                Text(flag)
                            }
                            Text(verbatim: phoneNumber.formatted(.international))
                            
                            if phoneNumber.isPrimary {
                                CapsuleTag(text: "Primary")
                                    .matchedGeometryEffect(id: "primaryCapsule", in: namespace)
                            }
                            
                            if phoneNumber.verification?.status != .verified {
                                CapsuleTag(text: "Unverified", style: .warning)
                            }
                        }
                        .font(.footnote)
                    } expandedContent: {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            primaryCallout(phoneNumber: phoneNumber)
                                .matchedGeometryEffect(id: "\(phoneNumber.id)", in: namespace)
                            
                            if phoneNumber.verification?.status != .verified {
                                unverifiedCallout(phoneNumber: phoneNumber)
                            }
                            
                            RemovePhoneNumberView(phoneNumber: phoneNumber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    }
                }
                
                Button(action: {
                    addPhoneNumberStep = .add
                }, label: {
                    Text("+ Add a phone number")
                })
                .font(.footnote.weight(.medium))
                .tint(clerkTheme.colors.textPrimary)
                .padding(.leading, 8)
                .sheet(item: $addPhoneNumberStep) { step in
                    UserProfileAddPhoneNumberView(initialStep: step)
                }
            }
        }
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    _ = Container.shared.clerk.register { Clerk.mock }
    return UserProfilePhoneNumberSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
