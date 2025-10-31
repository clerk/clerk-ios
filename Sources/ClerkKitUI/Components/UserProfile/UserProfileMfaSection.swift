//
//  UserProfileMfaSection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileMfaSection: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(UserProfileView.SharedState.self) private var sharedState

    @State private var addMfaHeight: CGFloat = 400

    var user: User? {
        clerk.user
    }

    var mfaPhoneNumbers: [PhoneNumber] {
        (user?.phoneNumbers ?? [])
            .filter { phoneNumber in
                phoneNumber.reservedForSecondFactor
            }
            .sorted { lhs, rhs in
                if lhs.defaultSecondFactor {
                    return true
                } else if rhs.defaultSecondFactor {
                    return false
                } else {
                    return lhs.createdAt < rhs.createdAt
                }
            }
    }

    var body: some View {
        @Bindable var sharedState = sharedState

        Section {
            VStack(spacing: 0) {
                if user?.totpEnabled == true {
                    UserProfileMfaRow(
                        style: .authenticatorApp,
                        isDefault: true
                    )
                }

                if clerk.environment.mfaPhoneCodeIsEnabled {
                    ForEach(mfaPhoneNumbers) { phoneNumber in
                        UserProfileMfaRow(
                            style: .sms(phoneNumber: phoneNumber),
                            isDefault: phoneNumber.defaultSecondFactor && user?.totpEnabled == false
                        )
                    }
                }

                if clerk.environment.mfaBackupCodeIsEnabled {
                    if user?.backupCodeEnabled == true {
                        UserProfileMfaRow(
                            style: .backupCodes
                        )
                    }
                }

                UserProfileButtonRow(text: "Add two-step verification") {
                    sharedState.chooseMfaTypeIsPresented = true
                }
            }
            .background(theme.colors.background)
        } header: {
            UserProfileSectionHeader(text: "TWO-STEP VERIFICATION")
        }
        .sheet(isPresented: $sharedState.chooseMfaTypeIsPresented) {
            UserProfileAddMfaView(contentHeight: $addMfaHeight)
                .presentationDetents([.height(addMfaHeight)])
        }
    }
}

#Preview {
    UserProfileMfaSection()
        .clerkPreviewMocks()
        .environment(\.clerkTheme, .clerk)
}

#endif
