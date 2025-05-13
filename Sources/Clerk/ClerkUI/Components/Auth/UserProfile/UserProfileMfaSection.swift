//
//  UserProfileMfaSection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileMfaSection: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    var environment: Clerk.Environment {
      clerk.environment
    }

    var user: User? {
      clerk.user
    }

    var mfaPhoneNumbers: [PhoneNumber] {
      user?.phoneNumbers.filter { phoneNumber in
        phoneNumber.reservedForSecondFactor
      } ?? []
    }

    var body: some View {
      Section {
        VStack(spacing: 0) {
          if user?.totpEnabled == true {
            UserProfileMfaRow(
              style: .authenticatorApp,
              isDefault: true
            )
          }

          if environment.isMfaPhoneCodeEnabled {
            ForEach(mfaPhoneNumbers) { phoneNumber in
              UserProfileMfaRow(
                style: .sms(phoneNumber: phoneNumber),
                isDefault: phoneNumber.defaultSecondFactor && user?.totpEnabled == false
              )
            }
          }

          if environment.isMfaBackupCodeEnabled {
            if user?.backupCodeEnabled == true {
              UserProfileMfaRow(
                style: .backupCodes
              )
            }
          }

          UserProfileButtonRow(text: "Add two-step verification") {
            // add two factor
          }
        }
        .background(theme.colors.background)
      } header: {
        UserProfileSectionHeader(text: "TWO-STEP VERIFICATION")
      }
    }
  }

  #Preview {
    UserProfileMfaSection()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
