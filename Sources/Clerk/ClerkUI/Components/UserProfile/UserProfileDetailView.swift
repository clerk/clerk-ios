//
//  UserProfileDetailView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

#if os(iOS)

  import Factory
  import Kingfisher
  import SwiftUI

  struct UserProfileDetailView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var addEmailAddressDestination: UserProfileAddEmailView.Destination?
    @State private var addPhoneNumberDestination: UserProfileAddPhoneView.Destination?
    @State private var addConnectedAccountIsPresented = false
    @State private var connectAccountSheetHeight: CGFloat = 200
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
            return lhs.createdAt < rhs.createdAt
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
            return lhs.createdAt < rhs.createdAt
          }
        }
    }
    
    var sortedExternalAccounts: [ExternalAccount] {
      (user?.externalAccounts.filter({ $0.verification?.status == .verified }) ?? [])
        .sorted { lhs, rhs in
          lhs.createdAt < rhs.createdAt
        }
    }

    @ViewBuilder
    private func emailRow(
      _ emailAddress: EmailAddress
    ) -> some View {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          WrappingHStack(alignment: .leading) {
            if user?.primaryEmailAddress == emailAddress {
              Badge(key: "Primary", style: .secondary)
            }
            
            if emailAddress.verification?.status != .verified {
              Badge(key: "Unverified", style: .warning)
            }
            
            if emailAddress.linkedTo?.isEmpty == false {
              Badge(key: "Linked", style: .secondary)
            }
          }

          Text(emailAddress.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer(minLength: 0)

        Menu {
          if user?.primaryEmailAddress != emailAddress, emailAddress.verification?.status == .verified {
            AsyncButton {
              await setEmailAsPrimary(emailAddress)
            } label: { isRunning in
              Text("Set as primary", bundle: .module)
            }
          }
          
          if emailAddress.verification?.status != .verified {
            Button {
              addEmailAddressDestination = .verify(emailAddress)
            } label: {
              Text("Verify", bundle: .module)
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
        .frame(width: 30, height: 30)
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
          WrappingHStack(alignment: .leading) {
            if user?.primaryPhoneNumber == phoneNumber {
              Badge(key: "Primary", style: .secondary)
            }
            
            if phoneNumber.verification?.status != .verified {
              Badge(key: "Unverified", style: .warning)
            }
            
            if phoneNumber.reservedForSecondFactor {
              Badge(key: "MFA reserved", style: .secondary)
            }
          }
          
          Text(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer()

        Menu {
          if user?.primaryPhoneNumber != phoneNumber, phoneNumber.verification?.status == .verified {
            AsyncButton {
              await setPhoneAsPrimary(phoneNumber)
            } label: { isRunning in
              Text("Set as primary", bundle: .module)
            }
          }
          
          if phoneNumber.verification?.status != .verified {
            Button {
              addPhoneNumberDestination = .verify(phoneNumber)
            } label: {
              Text("Verify", bundle: .module)
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
        .frame(width: 30, height: 30)
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
          WrappingHStack(alignment: .leading) {
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
            
            if externalAccount.verification?.status != .verified {
              Badge(key: "Unverified", style: .warning)
            }
          }

          if !externalAccount.emailAddress.isEmpty {
            Text(externalAccount.emailAddress)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.text)
              .frame(minHeight: 22)
          }
        }

        Spacer()

        Menu {
          if externalAccount.verification?.status != .verified {
            Button {
              
            } label: {
              Text("Verify", bundle: .module)
            }
          }
          
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
        .frame(width: 30, height: 30)
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
                      addEmailAddressDestination = .add
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
                      addPhoneNumberDestination = .add
                    }
                  }
                  .background(theme.colors.background)
                } header: {
                  UserProfileSectionHeader(text: "PHONE NUMBERS")
                }

                Section {
                  Group {
                    ForEach(sortedExternalAccounts) { externalAccount in
                      externalAccountRow(externalAccount)
                    }
                    
                    if !user.unconnectedProviders.isEmpty {
                      UserProfileButtonRow(text: "Connect account") {
                        addConnectedAccountIsPresented = true
                      }
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
      .sheet(item: $addEmailAddressDestination) {
        UserProfileAddEmailView(desintation: $0)
      }
      .sheet(item: $addPhoneNumberDestination) {
        UserProfileAddPhoneView(desintation: $0)
      }
      .sheet(isPresented: $addConnectedAccountIsPresented) {
        UserProfileAddConnectedAccountView(contentHeight: $connectAccountSheetHeight)
          .presentationDetents([.height(connectAccountSheetHeight)])
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
      .onChange(
        of: [
          addEmailAddressDestination != nil,
          addPhoneNumberDestination != nil,
          addConnectedAccountIsPresented
        ]
      ) {
        sharedState.applyBlur = $0.contains(true)
      }
      .onChange(of: removeResource) {
        if $0 != nil { isConfirmingRemoval = true }
      }
      .task {
        try? await Client.get()
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
    let _ = Container.shared.clerk.register(factory: { @MainActor in
      .mock
    })

    NavigationStack {
      UserProfileDetailView()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
    }
  }

#endif
