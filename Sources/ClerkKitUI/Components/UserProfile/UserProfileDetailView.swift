//
//  UserProfileDetailView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDetailView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var addEmailAddressDestination: UserProfileAddEmailView.Destination?
  @State private var addPhoneNumberDestination: UserProfileAddPhoneView.Destination?
  @State private var addConnectedAccountIsPresented = false
  @State private var connectAccountSheetHeight: CGFloat = 200

  private var user: User? {
    clerk.user
  }

  private var canAddEmailAddress: Bool {
    clerk.environment?.emailIsImmutable != true
  }

  private var canAddPhoneNumber: Bool {
    clerk.environment?.phoneNumberIsImmutable != true
  }

  private var showEmailSection: Bool {
    clerk.environment?.emailIsEnabled == true && (canAddEmailAddress || !sortedEmails.isEmpty)
  }

  private var showPhoneNumberSection: Bool {
    clerk.environment?.phoneNumberIsEnabled == true && (canAddPhoneNumber || !sortedPhoneNumbers.isEmpty)
  }

  var sortedEmails: [EmailAddress] {
    (user?.emailAddresses ?? [])
      .sorted { lhs, rhs in
        if lhs == user?.primaryEmailAddress {
          true
        } else if rhs == user?.primaryEmailAddress {
          false
        } else {
          lhs.createdAt < rhs.createdAt
        }
      }
  }

  var sortedPhoneNumbers: [PhoneNumber] {
    (user?.phoneNumbers ?? [])
      .sorted { lhs, rhs in
        if lhs == user?.primaryPhoneNumber {
          true
        } else if rhs == user?.primaryPhoneNumber {
          false
        } else {
          lhs.createdAt < rhs.createdAt
        }
      }
  }

  var sortedExternalAccounts: [ExternalAccount] {
    (user?.externalAccounts.filter {
      $0.verification?.status == .verified || $0.verification?.error != nil
    } ?? [])
      .sorted { lhs, rhs in
        lhs.createdAt < rhs.createdAt
      }
  }

  var body: some View {
    ZStack {
      if let user {
        ScrollView {
          LazyVStack(spacing: 0) {
            if showEmailSection {
              Section {
                Group {
                  ForEach(sortedEmails) { emailAddress in
                    UserProfileEmailRow(emailAddress: emailAddress)
                  }

                  if canAddEmailAddress {
                    UserProfileButtonRow(text: "Add email address") {
                      addEmailAddressDestination = .add
                    }
                  }
                }
                .background(theme.colors.background)

              } header: {
                UserProfileSectionHeader(text: "EMAIL ADDRESSES")
              }
            }

            if showPhoneNumberSection {
              Section {
                Group {
                  ForEach(sortedPhoneNumbers) { phoneNumber in
                    UserProfilePhoneRow(phoneNumber: phoneNumber)
                  }

                  if canAddPhoneNumber {
                    UserProfileButtonRow(text: "Add phone number") {
                      addPhoneNumberDestination = .add
                    }
                  }
                }
                .background(theme.colors.background)
              } header: {
                UserProfileSectionHeader(text: "PHONE NUMBERS")
              }
            }

            if !(clerk.environment?.allSocialProviders ?? []).isEmpty {
              Section {
                Group {
                  ForEach(sortedExternalAccounts) { externalAccount in
                    UserProfileExternalAccountRow(externalAccount: externalAccount)
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
          }
          .animation(.default, value: sortedEmails)
          .animation(.default, value: sortedPhoneNumbers)
          .animation(.default, value: sortedExternalAccounts)
        }
        .background(theme.colors.muted)
        .securedByClerkFooter()
      }
    }
    .userProfileNavigationTitle("Manage account")
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .sheet(item: $addEmailAddressDestination) {
      UserProfileAddEmailView(desintation: $0)
    }
    .sheet(item: $addPhoneNumberDestination) {
      UserProfileAddPhoneView(desintation: $0)
    }
    .sheet(isPresented: $addConnectedAccountIsPresented) {
      UserProfileAddConnectedAccountView(contentHeight: $connectAccountSheetHeight)
      #if os(iOS)
      .presentationDetents([.height(connectAccountSheetHeight)])
      #endif
    }
    .task {
      _ = try? await clerk.refreshClient()
    }
    #if os(macOS)
    .frame(minWidth: 460, maxWidth: 620)
    #endif
  }
}

#Preview {
  NavigationStack {
    UserProfileDetailView()
      .clerkPreview()
      .environment(\.clerkTheme, .clerk)
  }
}

#endif
