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
    
    @State private var deleteSheetHeight: CGFloat = .zero
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
                    .font(.subheadline.weight(.medium))
                Text("This phone number is the primary phone number")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if phoneNumber.verification?.status == .verified {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set as primary phone number")
                    .font(.subheadline.weight(.medium))
                Text("Set this phone number as the primary to receive communications regarding your account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AsyncButton(options: [.disableButton, .showProgressView], action: {
                    await setAsPrimary(phoneNumber: phoneNumber)
                }, label: {
                    Text("Set as primary")
                        .font(.footnote.weight(.medium))
                })
                .tint(clerkTheme.colors.primary)
            }
        }
    }
    
    private func setAsPrimary(phoneNumber: PhoneNumber) async {
        do {
            try await phoneNumber.setAsPrimary()
        } catch {
            dump(error)
        }
    }
    
    @ViewBuilder
    private func unverifiedCallout(phoneNumber: PhoneNumber) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Verify phone number")
                .font(.subheadline.weight(.medium))
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
            .tint(clerkTheme.colors.primary)
        }
    }
    
    @ViewBuilder
    private func removeCallout(phoneNumber: PhoneNumber) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remove")
                .font(.subheadline.weight(.medium))
            Text("Delete this phone number and remove it from your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Remove phone number", role: .destructive) {
                confirmDeletePhoneNumber = phoneNumber
            }
            .font(.footnote.weight(.medium))
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
                        .font(.footnote.weight(.medium))
                    } expandedContent: {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            primaryCallout(phoneNumber: phoneNumber)
                                .matchedGeometryEffect(id: "\(phoneNumber.id)", in: namespace)
                            
                            if phoneNumber.verification?.status != .verified {
                                unverifiedCallout(phoneNumber: phoneNumber)
                            }
                            
                            removeCallout(phoneNumber: phoneNumber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    }
                    .sheet(item: $confirmDeletePhoneNumber) { phoneNumber in
                        UserProfileRemoveResourceView(resource: .phoneNumber(phoneNumber))
                            .padding(.top)
                            .readSize { deleteSheetHeight = $0.height }
                            .presentationDragIndicator(.visible)
                            .presentationDetents([.height(deleteSheetHeight)])
                    }
                }
                
                Button(action: {
                    addPhoneNumberStep = .add
                }, label: {
                    Text("+ Add a phone number")
                })
                .font(.footnote.weight(.medium))
                .tint(clerkTheme.colors.primary)
                .padding(.leading, 8)
            }
        }
        .sheet(item: $addPhoneNumberStep) { step in
            UserProfileAddPhoneNumberView(initialStep: step)
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
