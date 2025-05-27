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
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var addEmailAddressIsPresented = false
    @State private var addPhoneNumberIsPresented = false
    @State private var isConfirmingRemoval = false
    @State private var removeResource: RemoveResource?
    @State private var error: Error?

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
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          if user?.primaryEmailAddress == emailAddress {
            Badge(key: "Primary", style: .secondary)
          }

          Text(emailAddress.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer(minLength: 0)

        Menu {
          if user?.primaryEmailAddress != emailAddress {
            AsyncButton {
              await setEmailAsPrimary(emailAddress)
            } label: { isRunning in
              Text("Set as primary", bundle: .module)
            }
          }

          Button(role: .destructive) {
            removeResource = .email(emailAddress)
          } label: {
            Text("Remove email", bundle: .module)
          }

        } label: {
          Image("icon-three-dots-vertical", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundColor(theme.colors.textSecondary)
            .frame(width: 20, height: 20)
        }
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
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          if user?.primaryPhoneNumber == phoneNumber {
            Badge(key: "Primary", style: .secondary)
          }
          Text(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer()

        Menu {
          if user?.primaryPhoneNumber != phoneNumber {
            AsyncButton {
              await setPhoneAsPrimary(phoneNumber)
            } label: { isRunning in
              Text("Set as primary", bundle: .module)
            }
          }

          Button(role: .destructive) {
            removeResource = .phoneNumber(phoneNumber)
          } label: {
            Text("Remove phone", bundle: .module)
          }

        } label: {
          Image("icon-three-dots-vertical", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundColor(theme.colors.textSecondary)
            .frame(width: 20, height: 20)
        }
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
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            KFImage(
              externalAccount.oauthProvider.iconImageUrl(darkMode: colorScheme == .dark)
            )
            .resizable()
            .placeholder {
              #if DEBUG
                Image(systemName: "globe")
                  .resizable()
                  .scaledToFit()
              #endif
            }
            .fade(duration: 0.25)
            .scaledToFit()
            .frame(width: 20, height: 20)

            Text(externalAccount.oauthProvider.name)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.textSecondary)
              .frame(minHeight: 20)
          }

          Text(externalAccount.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer()

        Menu {
          Button(role: .destructive) {
            removeResource = .externalAccount(externalAccount)
          } label: {
            Text("Remove connection", bundle: .module)
          }

        } label: {
          Image("icon-three-dots-vertical", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundColor(theme.colors.textSecondary)
            .frame(width: 20, height: 20)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(theme.colors.background)
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
                  Group {
                    ForEach(sortedEmails) { emailAddress in
                      emailRow(emailAddress)
                    }

                    UserProfileButtonRow(text: "Add email address") {
                      addEmailAddressIsPresented = true
                    }
                  }
                  .background(theme.colors.background)

                } header: {
                  UserProfileSectionHeader(text: "EMAIL ADDRESSES")
                }

                Section {
                  Group {
                    ForEach(sortedPhoneNumbers) { phoneNumber in
                      phoneRow(phoneNumber)
                    }

                    UserProfileButtonRow(text: "Add phone number") {
                      addPhoneNumberIsPresented = true
                    }
                  }
                  .background(theme.colors.background)
                } header: {
                  UserProfileSectionHeader(text: "PHONE NUMBERS")
                }

                Section {
                  Group {
                    ForEach(user.externalAccounts) { externalAccount in
                      externalAccountRow(externalAccount)
                    }

                    UserProfileButtonRow(text: "Connect account") {
                      // present connect account
                    }
                  }
                  .background(theme.colors.background)
                } header: {
                  UserProfileSectionHeader(text: "CONNECTED ACCOUNTS")
                }
              }
              .animation(.default, value: sortedEmails)
              .animation(.default, value: sortedPhoneNumbers)
              .animation(.default, value: user.externalAccounts)
            }
            .background(theme.colors.backgroundSecondary)

            SecuredByClerkView()
              .padding(16)
              .frame(maxWidth: .infinity)
              .background(theme.colors.backgroundSecondary)
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Profile", bundle: .module)
            .font(theme.fonts.headline)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.text)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .sheet(isPresented: $addEmailAddressIsPresented) {
        UserProfileAddEmailView()
      }
      .sheet(isPresented: $addPhoneNumberIsPresented) {
        UserProfileAddPhoneView()
      }
      .confirmationDialog(
        removeResource?.messageLine1 ?? "",
        isPresented: $isConfirmingRemoval,
        titleVisibility: .visible,
        actions: {
          AsyncButton(role: .destructive) {
            await removeResource(removeResource)
          } label: { isRunning in
            Text(removeResource?.title ?? "", bundle: .module)
          }
        }
      )
      .onChange(of: [addEmailAddressIsPresented]) { _, newValue in
        sharedState.applyBlur = newValue.contains(true)
      }
      .onChange(of: removeResource) {
        if $0 != nil { isConfirmingRemoval = true }
      }
    }
  }

  extension UserProfileDetailView {

    private func setEmailAsPrimary(_ email: EmailAddress) async {
      do {
        try await user?.update(.init(primaryEmailAddressId: email.id))
      } catch {
        self.error = error
      }
    }

    private func setPhoneAsPrimary(_ phone: PhoneNumber) async {
      do {
        try await user?.update(.init(primaryPhoneNumberId: phone.id))
      } catch {
        self.error = error
      }
    }

    private func removeResource(_ resource: RemoveResource?) async {
      defer { removeResource = nil }
      
      do {
        try await resource?.deleteAction()
      } catch {
        self.error = error
      }
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
