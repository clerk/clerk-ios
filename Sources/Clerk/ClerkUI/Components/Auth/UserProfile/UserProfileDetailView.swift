//
//  UserProfileDetailView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  struct UserProfileDetailView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var user: User? {
      clerk.user
    }

    var sortedEmails: [EmailAddress] {
      (user?.emailAddresses ?? [])
        .sorted { lhs, rhs in
          if lhs == user?.primaryEmailAddress {
            return true
          } else if rhs == user?.primaryEmailAddress {
            return false
          } else {
            return false
          }
        }
    }
    
    var sortedPhoneNumbers: [PhoneNumber] {
      (user?.phoneNumbers ?? [])
        .sorted { lhs, rhs in
          if lhs == user?.primaryPhoneNumber {
            return true
          } else if rhs == user?.primaryPhoneNumber {
            return false
          } else {
            return false
          }
        }
    }

    @ViewBuilder
    private func emailRow(
      _ emailAddress: EmailAddress
    ) -> some View {
      VStack(alignment: .leading, spacing: 4) {
        if user?.primaryEmailAddress == emailAddress {
          Text("primary", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.textSecondary)
            .frame(minHeight: 20)
        }
        Text(emailAddress.emailAddress)
          .font(theme.fonts.body)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
    }

    @ViewBuilder
    private func phoneRow(
      _ phoneNumber: PhoneNumber
    ) -> some View {
      VStack(alignment: .leading, spacing: 4) {
        if user?.primaryPhoneNumber == phoneNumber {
          Text("primary", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.textSecondary)
            .frame(minHeight: 20)
        }
        Text(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
          .font(theme.fonts.body)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
    }

    @ViewBuilder
    private func externalAccountRow(
      _ externalAccount: ExternalAccount
    ) -> some View {
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
          Text(externalAccount.oauthProvider.name)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.textSecondary)
            .frame(minHeight: 20)
          Text(externalAccount.emailAddress)
            .font(theme.fonts.body)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer()

        KFImage(
          externalAccount.oauthProvider.iconImageUrl(darkMode: colorScheme == .dark)
        )
        .resizable()
        .placeholder {
          #if DEBUG
            Image(systemName: "globe")
              .resizable()
              .scaledToFit()
              .frame(width: 21, height: 21)
          #endif
        }
        .fade(duration: 0.25)
        .scaledToFit()
        .frame(width: 18, height: 18)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
    }

    var body: some View {
      ZStack {        
        if let user {
          VStack(spacing: 0) {
            ScrollView {
              VStack(spacing: 0) {
                Section {
                  ForEach(sortedEmails) { emailAddress in
                    emailRow(emailAddress)
                  }
                } header: {
                  UserProfileSectionHeader(text: "EMAIL ADDRESSES")
                }

                Section {
                  ForEach(sortedPhoneNumbers) { phoneNumber in
                    phoneRow(phoneNumber)
                  }
                } header: {
                  UserProfileSectionHeader(text: "PHONE NUMBERS")
                }

                Section {
                  ForEach(user.externalAccounts) { externalAccount in
                    externalAccountRow(externalAccount)
                  }
                } header: {
                  UserProfileSectionHeader(text: "CONNECTED ACCOUNTS")
                }
              }
            }
            .background(theme.colors.background)

            SecuredByClerkView()
              .padding(16)
              .frame(maxWidth: .infinity)
              .background(theme.colors.backgroundSecondary)
          }
        }
      }
      .toolbarBackground(theme.colors.backgroundSecondary, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Account", bundle: .module)
            .font(theme.fonts.headline)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.text)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .background(theme.colors.background)
    }
  }

  #Preview {
    NavigationStack {
      UserProfileDetailView()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
    }
  }

#endif
